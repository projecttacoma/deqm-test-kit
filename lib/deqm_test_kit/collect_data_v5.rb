# frozen_string_literal: true

require 'json'
require_relative '../utils/collect_data_utils'

module DEQMTestKit
  # tests for $collect-data (DEQM v5.0.0)
  # rubocop:disable Metrics/ClassLength
  class CollectDataV5 < Inferno::TestGroup
    id :collect_data_v5
    title '$collect-data'
    description 'Ensure FHIR server can perform the $collect-data operation'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    additional_measure_options = JSON.parse(File.read('./lib/fixtures/measureCheckBoxes.json'))
    measure_id_args = {
      type: 'radio',
      optional: false,
      default: 'CMS0334FHIRPCCesareanBirth',
      options: measure_options,
      title: 'Measure Title'
    }
    additional_measures_args = {
      type: 'checkbox',
      optional: true,
      options: additional_measure_options,
      title: 'Additional Measure Ids',
      default: ['']
    }
    custom_measure_id_args = {
      type: 'text',
      optional: true,
      title: 'Custom Measure ID',
      description: 'If you selected "Other" above or want to provide a custom Measure ID, enter it here.'
    }
    test do
      include CollectDataUtils

      title 'GET Measure/$collect-data with one measureId, periodStart, periodEnd'
      id 'collect-data-one-measure-get'
      description %(GET Measure/$collect-data with one measureId, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = collect_data_body(
          measure_ids: [selected_measure_id(custom_id: custom_measure_id, id: measure_id)],
          period_start: period_start,
          period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', operation_method: :get,
                                                          body: FHIR::Parameters.new(body))
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 1)
      end
    end

    test do
      include CollectDataUtils

      title 'POST Measure/$collect-data with one measureId, periodStart, periodEnd'
      id 'collect-data-one-measure-post'
      description %(POST Measure/$collect-data with one measureId, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        body = collect_data_body(
          measure_ids: [selected_measure_id(custom_id: custom_measure_id, id: measure_id)],
          period_start: period_start,
          period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, 1)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'GET Measure/$collect-data with two measureIds, periodStart, periodEnd'
      id 'collect-data-two-measure-get'
      description %(GET Measure/$collect-data with two measureIds, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :additional_measures, **additional_measures_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        measure_ids = [selected_measure_id(custom_id: custom_measure_id, id: measure_id)]
        measure_ids += additional_measures if additional_measures&.any?

        body = collect_data_body(
          measure_ids: measure_ids,
          period_start: period_start,
          period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', operation_method: :get,
                                                          body: FHIR::Parameters.new(body))
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, measure_ids.length)
      end
    end

    test do
      include CollectDataUtils

      title 'POST Measure/$collect-data with two measureIds, periodStart, periodEnd'
      id 'collect-data-two-measure-post'
      description %(POST Measure/$collect-data with two measureIds, periodStart, periodEnd returns 200 and
      FHIR Parameters resource that contains at least one FHIR Bundle.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :additional_measures, **additional_measures_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        measure_ids = [selected_measure_id(custom_id: custom_measure_id, id: measure_id)]
        measure_ids += additional_measures if additional_measures&.any?

        body = collect_data_body(
          measure_ids: measure_ids,
          period_start: period_start,
          period_end: period_end
        )

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_bundles(parameters, measure_ids.length)
      end
    end

    # GET Measure/$collect-data with measureId and periodStart in request parameters returns 400 and
    # FHIR Operation Outcome when periodEnd was missing.
    test do
      include CollectDataUtils

      title 'GET Measure/$collect-data missing periodEnd returns HTTP 400 and OperationOutcome'
      id 'collect-data-missing-period-end-get-fail'
      description %(GET Measure/$collect-data with one measureId and periodStart returns 400 and
      FHIR OperationOutcome when periodEnd was missing.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'

      run do
        selected_id = selected_measure_id(custom_id: custom_measure_id, id: measure_id)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureId', valueId: selected_id },
            { name: 'periodStart', valueDate: period_start }
            # periodEnd intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$collect-data', operation_method: :get, body: FHIR::Parameters.new(body))
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$collect-data with measureId and periodStart in request body returns 400 and
    # FHIR Operation Outcome when periodEnd was missing.
    test do
      include CollectDataUtils

      title 'POST Measure/$collect-data missing periodEnd returns HTTP 400 and OperationOutcome'
      id 'collect-data-missing-period-end-post-fail'
      description %(POST Measure/$collect-data with one measureId and periodStart returns 400 and
      FHIR OperationOutcome when periodEnd was missing.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'

      run do
        selected_id = selected_measure_id(custom_id: custom_measure_id, id: measure_id)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureId', valueId: selected_id },
            { name: 'periodStart', valueDate: period_start }
            # periodEnd intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # GET Measure/$collect-data with measureId and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when periodStart was missing.
    test do
      include CollectDataUtils

      title 'GET Measure/$collect-data missing periodStart returns HTTP 400 and OperationOutcome'
      id 'collect-data-missing-period-start-get-fail'
      description %(GET Measure/$collect-data with one measureId and periodEnd returns 400 and
      FHIR OperationOutcome when periodStart was missing.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        selected_id = selected_measure_id(custom_id: custom_measure_id, id: measure_id)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureId', valueId: selected_id },
            { name: 'periodEnd', valueDate: period_end }
            # periodStart intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$collect-data', operation_method: :get, body: FHIR::Parameters.new(body))
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$collect-data with measureId and periodEnd in request body returns 400 and
    # FHIR Operation Outcome when periodStart was missing.
    test do
      include CollectDataUtils

      title 'POST Measure/$collect-data missing periodStart returns HTTP 400 and OperationOutcome'
      id 'collect-data-missing-period-start-post-fail'
      description %(POST Measure/$collect-data with one measureId and periodEnd returns 400 and
      FHIR OperationOutcome when periodStart was missing.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'

      run do
        selected_id = selected_measure_id(custom_id: custom_measure_id, id: measure_id)
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureId', valueId: selected_id },
            { name: 'periodEnd', valueDate: period_end }
            # periodStart intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # GET Measure/$collect-data with periodStart and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when measureId was missing.
    test do
      title 'GET Measure/$collect-data missing measureId returns HTTP 400 and OperationOutcome'
      id 'collect-data-missing-measure-id-get-fail'
      description %(GET Measure/$collect-data with one periodStart and periodEnd returns 400 and
      FHIR OperationOutcome when measureId was missing.)

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
            # measureId intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$collect-data', operation_method: :get, body: FHIR::Parameters.new(body))
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end

    # POST Measure/$collect-data with periodStart and periodEnd in request parameters returns 400 and
    # FHIR Operation Outcome when measureId was missing.
    test do
      title 'POST Measure/$collect-data missing measureId returns HTTP 400 and OperationOutcome'
      id 'collect-data-missing-measure-id-post-fail'
      description %(POST Measure/$collect-data with one periodStart and periodEnd returns 400 and
      FHIR OperationOutcome when measureId was missing.)

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
            # measureId intentionally omitted
          ]
        }

        result = fhir_operation('/Measure/$collect-data', body: body)
        assert_response_status(400)
        assert result.resource.is_a?(FHIR::OperationOutcome)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
