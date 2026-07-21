# frozen_string_literal: true

require 'json'
require_relative '../utils/collect_data_utils'

module DEQMTestKit
  # tests for $collect-data (DEQM UV v1.0.0) with dataEndpoint parameter
  class CollectDataEndpointV1 < Inferno::TestGroup
    id :collect_data_endpoint_v1
    title '$collect-data with dataEndpoint'
    description 'Ensure FHIR server can perform the $collect-data operation with the dataEndpoint parameter'

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

    data_endpoint_args = {
      title: 'dataEndpoint',
      type: 'textarea',
      description: 'An endpoint resource in JSON format to use to collect the data of interest for the specified
      measures.'
    }

    test do
      include CollectDataUtils

      title 'POST Measure/$collect-data with one measureUrl, required params, subject Patient, and dataEndpoint'
      id 'collect-data-one-measure-data-endpoint-subject-patient'
      description %(POST Measure/$collect-data with one measureUrl, periodStart, periodEnd, subject Patient, and
      dataEndpoint returns 200 and FHIR Parameters resource that contains one FHIR Bundle with one FHIR MeasureReport.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :data_endpoint, **data_endpoint_args
      input :patient_id, title: 'Patient ID'

      run do
        body = collect_data_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end,
          data_endpoint: data_endpoint, patient_id: patient_id
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

      title 'POST Measure/$collect-data with two measureUrls, required params, subject Patient, and dataEndpoint'
      id 'collect-data-two-measure-data-endpoint-subject-patient'
      description %(POST Measure/$collect-data with two measureUrls, periodStart, periodEnd, subject Patient, and
      dataEndpoint returns 200 and FHIR Parameters resource that contains one FHIR Bundle with two FHIR MeasureReports.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :data_endpoint, **data_endpoint_args
      input :patient_id, title: 'Patient ID'

      run do
        body = collect_data_body(
          measure_urls: selected_measure_urls, period_start: period_start, period_end: period_end,
          data_endpoint: data_endpoint, patient_id: patient_id
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
end
