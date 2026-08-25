# frozen_string_literal: true

require 'json'
require_relative '../utils/collect_data_utils'

module DEQMTestKit
  # tests for $collect-data subjectGroup(DEQM UV v1.0.0)
  class CollectDataV1SubjectGroup < Inferno::TestGroup
    id :collect_data_v1_subjectGroup
    title '$collect-data with subjectGroup'
    description 'Ensure FHIR server can perform the $collect-data operation with subjectGroup'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

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
      description: 'If you selected "Other" above, enter it here.'
    }
    custom_additional_measure_url_args = {
      type: 'text',
      optional: true,
      title: 'Custom Additional Measure URL',
      description: 'If you selected "Other" for the additional Measure URL, enter it here.'
    }

    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'POST Measure/$collect-data with one measureUrl, periodStart, periodEnd, and subjectGroup'
      id 'collect-data-one-measure-post-subject-group'
      description %(POST Measure/$collect-data with one measureUrl, periodStart, periodEnd, and
      subjectGroup returns 200 and FHIR Parameters resource that contains X (patient count)
      number of FHIR Bundles that each contain one MeasureReport)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)

        body = collect_data_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url, url: measure_url)],
          period_start: period_start,
          period_end: period_end,
          patient_id_list: patient_id_list
        )

        result = fhir_operation('/Measure/$collect-data', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1)
        validate_number_of_bundles(parameters, patient_id_list.length)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'POST Measure/$collect-data with two measureUrls, periodStart, periodEnd, and subjectGroup'
      id 'collect-data-two-measures-post-subject-group'
      description %(POST Measure/$collect-data with two measureUrls, periodStart, periodEnd, and
      subjectGroup returns 200 and FHIR Parameters resource that contains X (patient count)
      number of FHIR Bundles that each contain two MeasureReports)

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

        body = collect_data_body(
          measure_urls: selected_measure_urls,
          period_start: period_start,
          period_end: period_end,
          patient_id_list: patient_id_list
        )

        result = fhir_operation('/Measure/$collect-data', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2)
        validate_number_of_bundles(parameters, patient_id_list.length)
      end
    end
  end
end
