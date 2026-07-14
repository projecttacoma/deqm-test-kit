# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $collect-data (DEQM UV v1.0.0) with dataEndpoint parameter
  class CollectDataEndpointV1 < Inferno::TestGroup
    # module for shared code for $collect-data with dataEndpoint parameter assertions and requests
    module CollectDataEndpointHelpers
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

      def validate_parameters_contains_bundles(parameters, measure_count)
        assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
        assert parameters.parameter.any?, 'Expected at least one parameter entry in Parameters resource'

        parameters.parameter.each do |param|
          assert param.resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
          validate_bundles_contain_measure_report(param.resource, measure_count)
        end
      end

      def validate_number_of_bundles(parameters, bundle_count)
        assert parameters.parameter.length == bundle_count,
               "Expected #{bundle_count} Bundle(s), got #{parameters.parameter.length}"
      end

      def validate_bundles_contain_measure_report(bundle, measure_count)
        assert bundle.entry.is_a?(Array), 'Expected Bundle.entry to be an array'
        assert bundle.entry.any?, 'Expected at least one entry in the Bundle'

        measure_reports = bundle.entry.map(&:resource).grep(FHIR::MeasureReport)
        assert measure_reports.length == measure_count,
               "Expected #{measure_count} MeasureReport(s), got #{measure_reports.length}"
      end

      def collect_data_body(period_start:, period_end:, measure_urls:, data_endpoint:, patient_id:) # rubocop:disable Metrics/MethodLength
        parameters = measure_urls.map do |url|
          {
            name: 'measureUrl',
            valueCanonical: url
          }
        end

        if patient_id
          parameters << {
            name: 'subject',
            valueString: "Patient/#{patient_id}"
          }
        end

        parameters << {
          name: 'periodStart',
          valueDate: period_start
        }

        parameters << {
          name: 'periodEnd',
          valueDate: period_end
        }

        parameters << {
          name: 'dataEndpoint',
          resource: JSON.parse(data_endpoint)
        }

        {
          resourceType: 'Parameters',
          parameter: parameters
        }
      end
    end

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
      include CollectDataEndpointHelpers

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
      include CollectDataEndpointHelpers

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
