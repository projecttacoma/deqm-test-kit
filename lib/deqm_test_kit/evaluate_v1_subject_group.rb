# frozen_string_literal: true

require 'json'
require_relative '../utils/evaluate_v1_utils'

module DEQMTestKit
  # tests for $evaluate subjectGroup (DEQM UV v1.0.0)
  class EvaluateV1SubjectGroup < Inferno::TestGroup # rubocop:disable Metrics/ClassLength
    id :evaluate_v1_subjectGroup
    title '$evaluate'
    description 'Ensure FHIR server can calculate a Measure using $evaluate operation with subjectGroup ' \
                '(DEQM UV v1.0.0)'

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

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
  end
end
