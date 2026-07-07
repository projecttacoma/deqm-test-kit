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

      def evaluate_request_body(period_start:, period_end:, measure_urls:) # rubocop:disable Metrics/MethodLength
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

      def validate_parameters_contains_bundles(parameters, measure_count)
        assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
        assert parameters.parameter.any?, 'Expected at least one parameter entry in Parameters resource'

        parameters.parameter.each do |param|
          assert param.resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
          validate_bundles_contain_measure_report(param.resource, measure_count)
        end
      end

      def validate_bundles_contain_measure_report(bundle, measure_count)
        assert bundle.entry.is_a?(Array), 'Expected Bundle.entry to be an array'
        assert bundle.entry.any?, 'Expected at least one entry in the Bundle'

        measure_reports = bundle.entry.map(&:resource).grep(FHIR::MeasureReport)
        assert measure_reports.length == measure_count,
               "Expected #{measure_count} MeasureReport(s), got #{measure_reports.length}"
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
      description %(Measure/$evaluate with one measureUrl and without reportType (defaults to reportType=summary)
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

        validate_parameters_contains_bundles(parameters, 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with one measureUrl, required params (default reportType=summary)'
      id 'evaluate-one-measure-summary-post'
      description %(Measure/$evaluate with one measureUrl and without reportType (defaults to reportType=summary)
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
        validate_parameters_contains_bundles(parameters, 1)
      end
    end

    test do
      include MeasureEvaluationHelpers

      # This doesn't seem to be possible with Inferno DSL fhir_operation
      title 'GET Measure/$evaluate with two measureUrls, required params (default reportType=summary)'
      id 'evaluate-two-measure-summary-get'
      description %(Measure/$evaluate with two measureUrls and without reportType (defaults to reportType=summary)
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
        validate_parameters_contains_bundles(parameters, 2)
      end
    end

    test do
      include MeasureEvaluationHelpers

      title 'POST Measure/$evaluate with two measureUrls, required params (default reportType=summary)'
      id 'evaluate-two-measure-summary-post'
      description %(Measure/$evaluate with two measureUrls and without reportType (defaults to reportType=summary)
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
        validate_parameters_contains_bundles(parameters, 2)
      end
    end
  end
end
