# frozen_string_literal: true

module DEQMTestKit
  # Utility functions in support of the evaluate test groups
  module EvaluateUtils
    def measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
      fhir_operation("/Measure/#{measure_id}/$#{config.options[:endpoint_name]}?#{params}")
      assert_error(expected_status)
    end

    def selected_measure_id
      return custom_measure_id.strip if measure_id == 'Other' && custom_measure_id&.strip&.length&.positive? # rubocop:disable Style/SafeNavigationChainLength

      measure_id
    end

    def validate_parameters_contains_measurereport_bundles(parameters)
      assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
      assert parameters.parameter.any?, 'Expected at least one parameter entry in Parameters resource'

      parameters.parameter.each do |param|
        assert param.resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
        validate_bundle_contains_measure_report(param.resource)
      end
    end

    def validate_bundle_contains_measure_report(bundle)
      assert bundle.entry.is_a?(Array), 'Expected Bundle.entry to be an array'
      assert bundle.entry.any?, 'Expected at least one entry in Bundle'

      measure_reports = bundle.entry.map(&:resource).grep(FHIR::MeasureReport)
      assert measure_reports.any?, 'Expected at least one MeasureReport in Bundle'

      measure_reports.each { |report| validate_measure_report_fields(report) }
    end

    def validate_measure_report_fields(report) # rubocop:disable Metrics/AbcSize
      assert report.status == 'complete', 'Expected MeasureReport.status to be "complete"'
      assert report.measure.present?, 'MeasureReport.measure is missing'
      assert report.period.present?, 'MeasureReport.period is missing'
      assert report.period.start.present?, 'MeasureReport.period.start is missing'
      assert report.period.end.present?, 'MeasureReport.period.end is missing'
      assert %w[individual summary subject-list].include?(report.type),
             "Unexpected MeasureReport.type: #{report.type}"
    end
  end
end
