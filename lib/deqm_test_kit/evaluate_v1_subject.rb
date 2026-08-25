# frozen_string_literal: true

require 'json'
require_relative '../utils/evaluate_v1_utils'

module DEQMTestKit
  # tests for $evaluate subject (DEQM UV v1.0.0)
  class EvaluateV1Subject < Inferno::TestGroup # rubocop:disable Metrics/ClassLength
    id :evaluate_v1_subject
    title '$evaluate'
    description 'Ensure FHIR server can calculate a Measure using $evaluate operation with subject (DEQM UV v1.0.0)'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
  end
end
