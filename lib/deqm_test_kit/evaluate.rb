# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate (DEQM v5.0.0)
  # rubocop:disable Metrics/ClassLength
  class Evaluate < Inferno::TestGroup
    # module for shared code for $evaluate assertions and requests
    module MeasureEvaluationHelpers
      def measure_evaluation_assert_success(params, expected_status: 200)
        fhir_operation("/Measure/#{measure_id}/$#{config.options[:endpoint_name]}?#{params}")
        assert_response_status(expected_status)

        # For v5.0.0 $evaluate, we expect a Parameters resource
        assert resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{resource&.class}"

        # Validate the Parameters resource structure
        validate_parameters_contains_measurereport_bundles(resource)
      end

      def measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
        fhir_operation("/Measure/#{measure_id}/$#{config.options[:endpoint_name]}?#{params}")
        assert_error(expected_status)
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

        measure_reports = bundle.entry.map(&:resource).select { |res| res.is_a?(FHIR::MeasureReport) }
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

    id :evaluate
    description 'Ensure FHIR server can calculate a measure using $evaluate operation (DEQM v5.0.0)'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'ColorectalCancerScreeningsFHIR',
                        options: measure_options, title: 'Measure Title' }
    additional_measures_args = { type: 'checkbox', optional: true,
                                 options: measure_options, title: 'Additional Measure Ids', default: [''] }

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
    INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'
    INVALID_START_DATE = 'INVALID_START_DATE'

    test do
      include MeasureEvaluationHelpers
      title 'Check operation output matches parameter specifications'
      id 'evaluate-01'
      description %(Server returns a Parameters resource with one or more Bundles, each containing at least one
        DEQM MeasureReport (Individual, Summary, or Subject List), and subsequent entries in the bundle are
        data-of-interest. The response must always be wrapped in a Parameters resource, even if
        only one Bundle is returned.)

      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        result = fhir_operation("/Measure/#{measure_id}/$evaluate?#{params}")
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_measurereport_bundles(parameters)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation output with multiple measures using Measure/$evaluate'
      id 'evaluate-02'
      description %(Server should properly return a Parameters resource containing multiple Bundles,
        each with measure reports for different measures when provided multiple measure IDs
        using the Measure/$evaluate endpoint.)
      input :measure_id, **measure_id_args
      input :additional_measures, **additional_measures_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        measure_ids = [measure_id]
        measure_ids += additional_measures if additional_measures&.any?

        measure_params = measure_ids.map { |id| "measureId=#{id}" }.join('&')
        params = "#{measure_params}&periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"

        fhir_operation("/Measure/$evaluate?#{params}")
        assert_response_status(200)

        assert resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{resource&.class}"

        validate_parameters_contains_measurereport_bundles(resource)

        # Verify we have the expected number of bundles for each measure
        expected_bundle_count = measure_ids.length
        assert resource.parameter[0].resource.entry.length >= expected_bundle_count,
               "Expected at #{expected_bundle_count} bundles, got #{resource.parameter[0].resource.entry.length}"
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for individual report with required query parameters'
      id 'evaluate-03'
      description %(Server should properly return a Parameters resource containing Bundles with individual
        measure reports when provided a Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_success(params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for subject-list report with required query parameters'
      id 'evaluate-04'
      description %(Server should properly return a Parameters resource containing Bundles with subject-list
        measure reports when provided a Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject-list"
        measure_evaluation_assert_success(params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for population report with required query parameters'
      id 'evaluate-05'
      description %(Server should properly return a Parameters resource containing Bundles with population
        measure reports when provided required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population"
        measure_evaluation_assert_success(params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for population report with Group subject'
      id 'evaluate-06'
      description %(Server should properly return a Parameters resource containing Bundles with population
        measure reports when provided a Group ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'
      input :group_id, title: 'Group ID'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population&subject=Group/#{group_id}"
        measure_evaluation_assert_success(params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for invalid measure ID'
      id 'evaluate-07'
      description 'Request returns a 404 error when the given measure ID cannot be found.'
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, INVALID_MEASURE_ID, expected_status: 404)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for invalid patient ID'
      id 'evaluate-08'
      description 'Request returns a 404 error when the given patient ID cannot be found'
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
        measure_evaluation_assert_failure(params, measure_id, expected_status: 404)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for missing required query parameter'
      id 'evaluate-09'
      description %(Server should not perform calculation and return a 400 response code
    when one of the required query parameters is omitted from the request. In this test,
      the measurement period start is omitted from the request.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for missing subject query parameter (subject report type)'
      id 'evaluate-10'
      description %(Server should not perform calculation and return a 400 response code
    when the subject report type is specified but no subject has been specified in the
      query parameters.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for invalid reportType'
      id 'evaluate-11'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" \
                 "&reportType=#{INVALID_REPORT_TYPE}"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for invalid parameter structure in input'
      id 'evaluate-12'
      description %(Server should return 400 when the request contains malformed parameters, such as missing '=' or
      invalid query format.)
      input :measure_id, **measure_id_args

      run do
        params = 'periodStart2019-01-01&periodEnd=2019-12-31&subjectPatient/123'
        measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for missing periodEnd parameter in input'
      id 'evaluate-13'
      description %(Server should return 400 when input is missing periodEnd parameter.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'

      run do
        params = "periodStart=#{period_start}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
