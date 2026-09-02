# frozen_string_literal: true

require 'json'
require_relative '../utils/collect_data_utils'

module DEQMTestKit
  # tests for $collect-data subject (DEQM UV v1.0.0)
  # rubocop:disable Metrics/ClassLength
  class CollectDataV1Subject < Inferno::TestGroup
    id :collect_data_v1_subject
    title '$collect-data with subject'
    description 'Ensure FHIR server can perform the $collect-data operation with subject'

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

    test do
      include CollectDataUtils

      title 'GET Measure/$collect-data with one measureUrl, periodStart, periodEnd, and subject=Patient/patientId'
      id 'collect-data-one-measure-get-subject-patient'
      description %(GET Measure/$collect-data with one measureUrl, periodStart, periodEnd, and subject=Patient/patientId
      returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that contains one MeasureReport)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = collect_data_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$collect-data', operation_method: :get,
                                                          body: FHIR::Parameters.new(body))

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1)
        validate_number_of_bundles(parameters, 1)
      end
    end

    test do
      include CollectDataUtils

      title 'POST Measure/$collect-data with one measureUrl, periodStart, periodEnd, and subject=Patient/patientId'
      id 'collect-data-one-measure-post-subject-patient'
      description %(POST Measure/$collect-data with one measureUrl, periodStart, periodEnd, and
      subject=Patient/patientId returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that
      contains one MeasureReport)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = collect_data_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$collect-data', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1)
        validate_number_of_bundles(parameters, 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'GET Measure/$collect-data with two measureUrls, periodStart, periodEnd, and subject=Patient/patientId'
      id 'collect-data-two-measure-get-subject-patient'
      description %(GET Measure/$collect-data with two measureUrls, periodStart, periodEnd, and
      subject=Patient/patientId returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that
      contains two MeasureReports)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = collect_data_body(
          measure_urls: selected_measure_urls, period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$collect-data', operation_method: :get,
                                                          body: FHIR::Parameters.new(body))

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2)
        validate_number_of_bundles(parameters, 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'POST Measure/$collect-data with two measureUrls, periodStart, periodEnd, and subject=Patient/patientId'
      id 'collect-data-two-measure-post-subject-patient'
      description %(POST Measure/$collect-data with two measureUrls, periodStart, periodEnd, and
      subject=Patient/patientId returns 200 and FHIR Parameters resource that contains exactly one FHIR Bundle that
      contains two MeasureReports)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'

      run do
        body = collect_data_body(
          measure_urls: selected_measure_urls, period_start: period_start, period_end: period_end,
          patient_id: patient_id
        )

        result = fhir_operation('/Measure/$collect-data', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 2)
        validate_number_of_bundles(parameters, 1)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
