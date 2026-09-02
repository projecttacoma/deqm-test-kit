# frozen_string_literal: true

require 'json'
require_relative '../utils/evaluate_v1_utils'

module DEQMTestKit
  # tests for $evaluate (DEQM UV v1.0.0)
  class EvaluateV1 < Inferno::TestGroup # rubocop:disable Metrics/ClassLength
    id :evaluate_v1
    title '$evaluate'
    description 'Ensure FHIR server can calculate a Measure using $evaluate operation (DEQM UV v1.0.0)'

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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

    # GET Measure/$evaluate with measureUrl and periodStart in request parameters returns 400 and
    # FHIR Operation Outcome when periodEnd was missing.
    test do
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
      include EvaluateV1Utils

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
