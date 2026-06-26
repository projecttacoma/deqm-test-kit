# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $collect-data (DEQM UV v1.0.0)
  # rubocop:disable Metrics/ClassLength
  class CollectDataV1 < Inferno::TestGroup
    # module for shared code for $collect-data assertions and requests
    module CollectDataHelpers
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

      def validate_parameters_contains_bundles(parameters)
        assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
        assert parameters.parameter.any?, 'Expected at least one parameter entry in Parameters resource'

        # Check that first parameter is a bundle, checking all of them will cause the test to timeout
        assert parameters.parameter[0].resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
      end

      def collect_data_body(period_start:, period_end:, measure_urls:) # rubocop:disable Metrics/MethodLength
        {
          resourceType: 'Parameters',
          parameter: [
            *measure_urls.map do |url|
              {
                name: 'measureUrl',
                valueCanonical: url
              }
            end,
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
      end
    end

    id :collect_data_v1
    title '$collect-data'
    description 'Ensure FHIR server can perform the $collect-data operation'

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
      include CollectDataHelpers

      title 'GET Measure/$collect-data with one measureUrl, periodStart, periodEnd'
      id 'collect-data-one-measure-get'
      description %(GET Measure/$collect-data with one measureUrl, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = collect_data_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', operation_method: :get,
                                                          body: FHIR::Parameters.new(body))
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters)
      end
    end

    test do
      include CollectDataHelpers

      title 'POST Measure/$collect-data with one measureUrl, periodStart, periodEnd'
      id 'collect-data-one-measure-post'
      description %(POST Measure/$collect-data with one measureUrl, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = collect_data_body(
          measure_urls: [selected_measure_url(custom_url: custom_measure_url,
                                              url: measure_url)], period_start: period_start, period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters)
      end
    end

    test do
      include CollectDataHelpers

      title 'GET Measure/$collect-data with one measureUrl, periodStart, periodEnd'
      id 'collect-data-two-measure-get'
      description %(GET Measure/$collect-data with two measureUrls, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = collect_data_body(
          measure_urls: selected_measure_urls,
          period_start: period_start,
          period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', operation_method: :get,
                                                          body: FHIR::Parameters.new(body))
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters)
      end
    end

    test do
      include CollectDataHelpers

      title 'POST Measure/$collect-data with one measureUrl, periodStart, periodEnd'
      id 'collect-data-two-measure-post'
      description %(POST Measure/$collect-data with two measureUrls, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_url, **measure_url_args
      input :custom_measure_url, **custom_measure_url_args
      input :additional_measure_url, **additional_measure_args
      input :custom_additional_measure_url, **custom_additional_measure_url_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = collect_data_body(
          measure_urls: selected_measure_urls,
          period_start: period_start,
          period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
