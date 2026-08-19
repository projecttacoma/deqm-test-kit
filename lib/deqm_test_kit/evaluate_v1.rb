# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate (DEQM UV v1.0.0)
  class EvaluateV1 < Inferno::TestGroup # rubocop:disable Metrics/ClassLength
    # module for shared code for $evaluate assertions and requests
    module MeasureEvaluationHelpers
      def selected_measure_url(custom_url:, url:, input_title: 'Measure URL',
                               custom_input_title: 'Custom Measure URL')
        return url unless url == 'Other'

        custom_url = custom_url.to_s.strip

        assert custom_url.length.positive?,
               "#{custom_input_title} is required when \"#{input_title}\" is \"Other\"."

        custom_url
      end

      def selected_additional_measure_url(custom_url:, url:)
        selected_measure_url(
          custom_url:,
          url:,
          input_title: 'Measure URL for additional Measure',
          custom_input_title: 'Custom Additional Measure URL'
        )
      end

      def selected_measure_urls
        [
          selected_measure_url(custom_url: custom_measure_url, url: measure_url),
          selected_additional_measure_url(custom_url: custom_additional_measure_url, url: additional_measure_url)
        ]
      end

      # rubocop:disable Metrics/MethodLength
      def evaluate_request_body(options) # rubocop:disable Metrics/AbcSize
        parameters = options[:measure_urls].map do |url|
          {
            name: 'measureUrl',
            valueCanonical: url
          }
        end

        if options[:patient_id_list]
          parameters << {
            name: 'subjectGroup',
            resource: {
              resourceType: 'Group',
              id: 'test-group-subjectGroup',
              type: 'person',
              actual: true,
              member: options[:patient_id_list].map do |patient_id|
                { entity: { reference: "Patient/#{patient_id}" } }
              end
            }
          }
        end

        if options[:patient_id]
          parameters << {
            name: 'subject',
            valueString: "Patient/#{options[:patient_id]}"
          }
        end

        if options[:group_id]
          parameters << {
            name: 'subject',
            valueString: "Group/#{options[:group_id]}"
          }
        end

        parameters << {
          name: 'periodStart',
          valueDate: options[:period_start]
        }

        parameters << {
          name: 'periodEnd',
          valueDate: options[:period_end]
        }

        if options[:report_type]
          parameters << {
            name: 'reportType',
            valueCode: options[:report_type]
          }
        end

        {
          resourceType: 'Parameters',
          parameter: parameters
        }
      end
      # rubocop:enable Metrics/MethodLength

      def validate_parameters_contains_bundles(parameters, measure_count, report_type, bundle_count = nil)
        parameter = parameters.parameter
        assert parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
        assert parameter.any?, 'Expected at least one parameter entry in Parameters resource'
        assert bundle_count.nil? || parameter.length == bundle_count,
               "Expected #{bundle_count} Bundle(s), got #{parameter.length}"
        parameter.each do |param|
          assert param.resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
          validate_bundles_contain_measure_report(param.resource, measure_count, report_type)
        end
      end

      def validate_bundles_contain_measure_report(bundle, measure_count, report_type)
        assert bundle.entry.is_a?(Array), 'Expected Bundle.entry to be an array'
        assert bundle.entry.any?, 'Expected at least one entry in the Bundle'

        measure_reports = bundle.entry.map(&:resource).grep(FHIR::MeasureReport)
        assert measure_reports.length == measure_count,
               "Expected #{measure_count} MeasureReport(s), got #{measure_reports.length}"
        validate_measure_report_type(measure_reports, report_type)
      end

      def validate_measure_report_type(measure_reports, report_type)
        measure_reports.each do |measure_report|
          next if measure_report.type == report_type

          assert false,
                 "Expected MeasureReport.type to be #{report_type.inspect}, got #{measure_report.type.inspect}"
        end
      end
    end

    id :evaluate_v1
    title '$evaluate'
    description 'Ensure FHIR server can calculate a Measure using $evaluate operation (DEQM UV v1.0.0)'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    include MeasureEvaluationHelpers

    measure_options = JSON.parse(File.read('./lib/fixtures/measureUrlRadioButton.json'))
    measure_url_args = {
      type: 'radio',
      optional: false,
      default: 'https://madie.cms.gov/Measure/CMS0334FHIRPCCesareanBirth',
      options: measure_options,
      title: 'Measure URL'
    }
    additional_measure_args = {
      type: 'radio',
      optional: false,
      options: measure_options,
      title: 'Measure URL for additional Measure'
    }
    custom_measure_url_args = {
      type: 'text',
      optional: true,
      title: 'Custom Measure URL',
      description: 'If you selected "Other" above or want to provide a custom Measure URL, enter it here.'
    }
    custom_additional_measure_url_args = {
      type: 'text',
      optional: true,
      title: 'Custom Additional Measure URL',
      description: 'If you selected "Other" for the additional Measure URL, enter it here.'
    }

    test do
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate with one measureUrl, required params (default reportType=summary)'
      id 'evaluate-one-measure-summary-get'
      description %(GET Measure/$evaluate with one measureUrl and without reportType (defaults to reportType=summary)
      returns 200 and FHIR Parameters resource.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)]
        )

        result = fhir_operation('/Measure/$evaluate', body: FHIR::Parameters.new(body), operation_method: :get)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'summary', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, required params (default reportType=summary)'
      id 'evaluate-one-measure-summary-post'
      description %(POST Measure/$evaluate with one measureUrl and without reportType (defaults to reportType=summary)
      returns 200 and FHIR Parameters resource.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)]
        )
        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 1, 'summary', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      # This doesn't seem to be possible with Inferno DSL fhir_operation
      title 'GET Measure/$evaluate with two measureUrls, required params (default reportType=summary)'
      id 'evaluate-two-measure-summary-get'
      description %(GET Measure/$evaluate with two measureUrls and without reportType (defaults to reportType=summary)
      returns 200 and FHIR Parameters resource.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: selected_measure_urls
        )

        result = fhir_operation('/Measure/$evaluate', operation_method: :get,
                                                      body: FHIR::Parameters.new(body))

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 2, 'summary')
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with two measureUrls, required params (default reportType=summary)'
      id 'evaluate-two-measure-summary-post'
      description %(POST Measure/$evaluate with two measureUrls and without reportType (defaults to reportType=summary)
      returns 200 and FHIR Parameters resource.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: selected_measure_urls
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 2, 'summary')
      end
    end

    # SUBJECT PATIENT REFERENCE
    test do
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate with one measureUrl, required params, and subject Patient reference (default
      reportType=individual)'
      id 'evaluate-one-measure-get-subject-patient'
      description %(GET Measure/$evaluate with one measureUrl, periodStart, periodEnd, and subject=Patient/patientId
      returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that contains one MeasureReport)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = evaluate_request_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$evaluate', operation_method: :get, body: FHIR::Parameters.new(body))

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'individual', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, required params, and subject Patient reference (default
      reportType=individual)'
      id 'evaluate-one-measure-post-subject-patient'
      description %(POST Measure/$evaluate with one measureUrl, periodStart, periodEnd, and subject=Patient/patientId
      returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that contains one MeasureReport)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = evaluate_request_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$evaluate', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'individual', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, subject Patient reference, and reportType=summary'
      id 'evaluate-one-measure-summary-post-subject-patient'
      description %(POST Measure/$evaluate with measureUrl, periodStart, periodEnd, subject=Patient/patientId, and
      reportType=summary returns 200 and FHIR parameters resource that contains one FHIR bundle with a summary report.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = evaluate_request_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          period_start: period_start,
          period_end: period_end,
          patient_id: patient_id,
          report_type: 'summary'
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'summary', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate with two measureUrls, required params, and subject Patient reference (default
      reportType=individual)'
      id 'evaluate-two-measure-get-subject-patient'
      description %(GET Measure/$evaluate with two measureUrls, periodStart, periodEnd, and subject=Patient/patientId
      returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that contains two MeasureReports)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = evaluate_request_body(
          measure_urls: selected_measure_urls, period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$evaluate', operation_method: :get, body: FHIR::Parameters.new(body))

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2, 'individual', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with two measureUrls, required params, and subject Patient reference
      (default reportType=individual)'
      id 'evaluate-two-measure-post-subject-patient'
      description %(POST Measure/$evaluate with two measureUrls, periodStart, periodEnd, and subject=Patient/patientId
      returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that contains two MeasureReports)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = evaluate_request_body(
          measure_urls: selected_measure_urls, period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$evaluate', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2, 'individual', 1)
      end
    end

    # SUBJECT GROUP REFERENCE
    test do
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate with one measureUrl, required params, and subject Group reference (default
      reportType=summary)'
      id 'evaluate-one-measure-get-subject-group-reference'
      description %(GET Measure/$evaluate with measureUrl, periodStart, periodEnd, and subject=Group/groupId
      returns 200 and a FHIR Parameters resource containing exactly one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :group_id, title: 'Group ID'

      run do
        body = evaluate_request_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          period_start: period_start,
          period_end: period_end,
          group_id: group_id
        )

        result = fhir_operation('/Measure/$evaluate', operation_method: :get, body: FHIR::Parameters.new(body))
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'summary', 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, required params, and subject Group reference (default
      reportType=summary)'
      id 'evaluate-one-measure-post-subject-group-reference'
      description %(POST Measure/$evaluate with measureUrl, periodStart, periodEnd, and subject=Group/groupId
      returns 200 and a FHIR Parameters resource containing exactly one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :group_id, title: 'Group ID'

      run do
        body = evaluate_request_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          period_start: period_start,
          period_end: period_end,
          group_id: group_id
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'summary', 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, subject Group reference, and reportType=individual'
      id 'evaluate-one-measure-individual-post-subject-group-reference'
      description %(POST Measure/$evaluate with measureUrl, periodStart, periodEnd, subject=Group/groupId,
      and reportType=individual returns 200 and a FHIR Parameters resource that contains a FHIR Bundle with
      an individual report for each patient in the group.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :group_id, title: 'Group ID'

      run do
        fhir_read(:group, group_id)
        assert_response_status(200)
        assert_resource_type(:group)
        group_member_count = resource.member&.length

        body = evaluate_request_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          period_start: period_start,
          period_end: period_end,
          group_id: group_id,
          report_type: 'individual'
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1, 'individual', group_member_count)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate with two measureUrls, required params, and subject Group reference (default
      reportType=summary)'
      id 'evaluate-two-measure-get-subject-group-reference'
      description %(GET Measure/$evaluate with two measureUrls, periodStart, periodEnd, and subject=Group/groupId
      returns 200 and a FHIR Parameters resource containing exactly one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :group_id, title: 'Group ID'

      run do
        body = evaluate_request_body(
          measure_urls: selected_measure_urls,
          period_start: period_start,
          period_end: period_end,
          group_id: group_id
        )

        result = fhir_operation('/Measure/$evaluate', operation_method: :get, body: FHIR::Parameters.new(body))
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2, 'summary', 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with two measureUrls, required params, and subject Group reference (default
      reportType=summary)'
      id 'evaluate-two-measure-post-subject-group-reference'
      description %(POST Measure/$evaluate with two measureUrls, periodStart, periodEnd, and subject=Group/groupId
      returns 200 and a FHIR Parameters resource containing exactly one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :group_id, title: 'Group ID'

      run do
        body = evaluate_request_body(
          measure_urls: selected_measure_urls,
          period_start: period_start,
          period_end: period_end,
          group_id: group_id
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2, 'summary', 1)
      end
    end

    # SUBJECTGROUP
    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, periodStart, periodEnd, and subjectGroup'
      id 'evaluate-one-measure-summary-post-subject-group'
      description %(POST Measure/$evaluate with one measureUrl, periodStart, periodEnd, and subjectGroup
      returns 200 and a FHIR Parameters resource containing one Bundle with one summary MeasureReport.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          patient_id_list: patient_id_list
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 1, 'summary', 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with two measureUrls, periodStart, periodEnd, and subjectGroup'
      id 'evaluate-two-measure-summary-post-subject-group'
      description %(POST Measure/$evaluate with two measureUrls, periodStart, periodEnd, and subjectGroup
      returns 200 and a FHIR Parameters resource containing one Bundle with two summary MeasureReports.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: selected_measure_urls,
          patient_id_list: patient_id_list
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 2, 'summary', 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, subjectGroup, and reportType=individual'
      id 'evaluate-one-measure-individual-post-subject-group'
      description %(POST Measure/$evaluate with one measureUrl, periodStart, periodEnd, subjectGroup, and
      reportType=individual returns 200 and one Bundle per Group member with one individual MeasureReport.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          patient_id_list: patient_id_list,
          report_type: 'individual'
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 1, 'individual', patient_id_list.length)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with two measureUrls, subjectGroup, and reportType=individual'
      id 'evaluate-two-measure-individual-post-subject-group'
      description %(POST Measure/$evaluate with two measureUrls, periodStart, periodEnd, subjectGroup, and
      reportType=individual returns 200 and one Bundle per Group member with two individual MeasureReports.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
        body = evaluate_request_body(
          period_start: period_start,
          period_end: period_end,
          measure_urls: selected_measure_urls,
          patient_id_list: patient_id_list,
          report_type: 'individual'
        )

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 2, 'individual', patient_id_list.length)
      end
    end

    # GET Measure/$evaluate with measureUrl and periodStart in request parameters returns 400 and
    # FHIR Operation Outcome when periodEnd was missing.
    test do
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate missing periodEnd returns HTTP 400 and OperationOutcome'
      id 'evaluate-missing-period-end-get-fail'
      description %(GET Measure/$evaluate with one measureUrl and periodStart returns 400 and
      FHIR OperationOutcome when periodEnd was missing.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'

      run do
        selected_url = selected_measure_url(custom_url: custom_measure_url, url: measure_url)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureUrl', valueCanonical: selected_url },
            { name: 'periodStart', valueDate: period_start }
            # periodEnd intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: FHIR::Parameters.new(body), operation_method: :get)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$evaluate with measureUrl and periodStart in request parameters returns 400 and
    # FHIR Operation Outcome when periodEnd was missing.
    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate missing periodEnd returns HTTP 400 and OperationOutcome'
      id 'evaluate-missing-period-end-post-fail'
      description %(POST Measure/$evaluate with one measureUrl and periodStart returns 400 and
      FHIR OperationOutcome when periodEnd was missing.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'

      run do
        selected_url = selected_measure_url(custom_url: custom_measure_url, url: measure_url)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureUrl', valueCanonical: selected_url },
            { name: 'periodStart', valueDate: period_start }
            # periodEnd intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # GET Measure/$evaluate with measureUrl and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when periodStart was missing.
    test do
      include MeasureEvaluationHelpers

      title 'GET Measure/$evaluate missing periodStart returns HTTP 400 and OperationOutcome'
      id 'evaluate-missing-period-start-get-fail'
      description %(GET Measure/$evaluate with one measureUrl and periodEnd returns 400 and
      FHIR OperationOutcome when periodStart was missing.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        selected_url = selected_measure_url(custom_url: custom_measure_url, url: measure_url)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureUrl', valueCanonical: selected_url },
            { name: 'periodEnd', valueDate: period_end }
            # periodStart intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: FHIR::Parameters.new(body), operation_method: :get)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$evaluate with measureUrl and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when periodStart was missing.
    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate missing periodStart returns HTTP 400 and OperationOutcome'
      id 'evaluate-missing-period-start-post-fail'
      description %(POST Measure/$evaluate with one measureUrl and periodEnd returns 400 and
      FHIR OperationOutcome when periodStart was missing.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        selected_url = selected_measure_url(custom_url: custom_measure_url, url: measure_url)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureUrl', valueCanonical: selected_url },
            { name: 'periodEnd', valueDate: period_end }
            # periodStart intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # GET Measure/$evaluate with periodStart and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when measureUrl was missing.
    test do
      title 'GET Measure/$evaluate missing measureUrl returns HTTP 400 and OperationOutcome'
      id 'evaluate-missing-measure-url-get-fail'
      description %(GET Measure/$evaluate with one periodStart and periodEnd returns 400 and
      FHIR OperationOutcome when measureUrl was missing.)

      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'periodStart',
              valueDate: period_start
            },
            {
              name: 'periodEnd',
              valueDate: period_end
            }
            # measureUrl intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: FHIR::Parameters.new(body), operation_method: :get)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$evaluate with periodStart and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when measureUrl was missing.
    test do
      title 'POST Measure/$evaluate missing measureUrl returns HTTP 400 and OperationOutcome'
      id 'evaluate-missing-measure-url-post-fail'
      description %(POST Measure/$evaluate with one periodStart and periodEnd returns 400 and
      FHIR OperationOutcome when measureUrl was missing.)

      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'periodStart',
              valueDate: period_start
            },
            {
              name: 'periodEnd',
              valueDate: period_end
            }
            # measureUrl intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # GET Measure/$evaluate with measureUrl, periodStart, periodEnd, subject, and subjectGroup in request parameters
    # returns 400 and FHIR Operation Outcome for providing both subject and subjectGroup parameters.
    test do # rubocop:disable Metrics/BlockLength
      title 'GET Measure/$evaluate with both subject and subjectGroup returns HTTP 400 and OperationOutcome'
      id 'evaluate-subject-and-subject-group-get-fail'
      description %(GET Measure/$evaluate with measureUrl, periodStart, periodEnd, subject, and subjectGroup
      returns 400 and FHIR OperationOutcome when both subject and subjectGroup were provided.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        selected_url = selected_measure_url(custom_url: custom_measure_url, url: measure_url)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureUrl', valueCanonical: selected_url },
            {
              name: 'subject',
              valueString: patient_id
            },
            {
              name: 'subjectGroup',
              valueString: 'Group/test-group'
            },
            {
              name: 'periodStart',
              valueDate: period_start
            },
            {
              name: 'periodEnd',
              valueDate: period_end
            }
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: FHIR::Parameters.new(body), operation_method: :get)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$evaluate with measureUrl, periodStart, periodEnd, subject, and subjectGroup in request parameters
    # returns 400 and FHIR Operation Outcome for providing both subject and subjectGroup parameters.
    test do # rubocop:disable Metrics/BlockLength
      title 'POST Measure/$evaluate with both subject and subjectGroup returns HTTP 400 and OperationOutcome'
      id 'evaluate-subject-and-subject-group-post-fail'
      description %(POST Measure/$evaluate with measureUrl, periodStart, periodEnd, subject, and subjectGroup
      returns 400 and FHIR OperationOutcome when both subject and subjectGroup were provided.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        selected_url = selected_measure_url(custom_url: custom_measure_url, url: measure_url)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureUrl', valueCanonical: selected_url },
            {
              name: 'subject',
              valueString: patient_id
            },
            {
              name: 'subjectGroup',
              resource: {
                resourceType: 'Group',
                id: 'test-group',
                member: [
                  {
                    entity: {
                      reference: "Patient/#{patient_id}"
                    }
                  }
                ]
              }
            },
            {
              name: 'periodStart',
              valueDate: period_start
            },
            {
              name: 'periodEnd',
              valueDate: period_end
            }
          ]
        }

        result = fhir_operation('/Measure/$evaluate', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end
  end
end
