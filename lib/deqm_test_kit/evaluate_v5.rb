# frozen_string_literal: true

require 'json'
require_relative '../utils/evaluate_utils'

module DEQMTestKit
  # tests for $evaluate (DEQM v5.0.0)
  # rubocop:disable Metrics/ClassLength
  class EvaluateV5 < Inferno::TestGroup
    id :evaluate_v5
    description 'Ensure FHIR server can calculate a measure using $evaluate operation (DEQM v5.0.0)'

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    additional_measure_options = JSON.parse(File.read('./lib/fixtures/measureCheckBoxes.json'))
    measure_id_args = {
      type: 'radio',
      optional: false,
      default: 'ColorectalCancerScreeningsFHIR',
      options: measure_options,
      title: 'Measure Title'
    }
    custom_measure_id_args = {
      type: 'text',
      optional: true,
      title: 'Custom Measure ID',
      description: 'If you selected "Other" above or want to provide a custom Measure ID, enter it here.'
    }
    additional_measures_args = {
      type: 'checkbox',
      optional: true,
      options: additional_measure_options,
      title: 'Additional Measure Ids',
      default: ['']
    }

    test do
      include EvaluateUtils

      title 'Measure/[id]/$evaluate (default reportType=population)'
      id 'evaluate-id-path-population'
      description %(Measure/[id]/$evaluate without reportType (defaults to reportType=population)
      returns 200 and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'periodStart', valueDate: period_start },
            { name: 'periodEnd', valueDate: period_end }
          ]
        }
        result = fhir_operation("/Measure/#{selected_measure_id}/$evaluate", body:)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{result.resource&.class}"

        validate_parameters_contains_measurereport_bundles(result.resource)
      end
    end

    test do
      include EvaluateUtils

      title 'Measure/$evaluate without reportType (defaults to reportType=population)'
      id 'evaluate-population'
      description %(Measure/$evaluate without reportType (defaults to reportType=population) returns 200
      and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'measureId', valueString: selected_measure_id },
            { name: 'periodStart', valueDate: period_start },
            { name: 'periodEnd', valueDate: period_end }
          ]
        }
        result = fhir_operation('/Measure/$evaluate', body:)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{result.resource&.class}"

        validate_parameters_contains_measurereport_bundles(result.resource)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with multiple measureIds without reportType (defaults to reportType=population)'
      id 'evaluate-multiple-measure-population'
      description %(Measure/$evaluate with multiple measureIds without reportType (defaults to reportType=population)
      returns 200 and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :additional_measures, **additional_measures_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        measure_ids = [selected_measure_id]
        measure_ids += additional_measures if additional_measures&.any?
        measure_params = measure_ids.map { |id| { name: 'measureId', valueString: id } }
        body = {
          resourceType: 'Parameters',
          parameter: [
            { name: 'periodStart', valueDate: period_start },
            { name: 'periodEnd', valueDate: period_end }
          ].concat(measure_params)
        }
        fhir_operation('/Measure/$evaluate', body:)

        assert_response_status(200)
        assert resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{resource&.class}"
        validate_parameters_contains_measurereport_bundles(resource)
        assert resource.parameter.length == 1,
               "Expected 1 Bundle for reportType=population and no subjects specified, got #{resource.parameter.length}"

        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == measure_ids.length,
               "Expected #{measure_ids.length} MeasureReports, got #{measure_reports.length}"
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
