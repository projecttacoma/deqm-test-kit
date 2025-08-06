# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate-measure (DEQM v3.0.0)
  # rubocop:disable Metrics/ClassLength
  class EvaluateMeasure < Inferno::TestGroup
    # module for shared code for $evaluate-measure assertions and requests
    module MeasureEvaluationHelpers
      def measure_evaluation_assert_success(_report_type, resource_type, params, expected_status: 200)
        fhir_operation("/Measure/#{measure_id}/$#{config.options[:endpoint_name]}?#{params}")
        assert_success(resource_type, expected_status)
      end

      def measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
        fhir_operation("/Measure/#{measure_id}/$#{config.options[:endpoint_name]}?#{params}")
        assert_error(expected_status)
      end
    end

    id :evaluate_measure
    description 'Ensure FHIR server can calculate a measure using $evaluate-measure operation (DEQM v3.0.0)'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'ColorectalCancerScreeningsFHIR',
                        options: measure_options, title: 'Measure Title' }

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
    INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'
    INVALID_START_DATE = 'INVALID_START_DATE'

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for individual report with required query parameters'
      id 'evaluate-measure-individual-with-patient-subject'
      description %(Server should properly return an individual measure report when provided a
        Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_success('individual', :measure_report, params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for subject-list report with required query parameters'
      id 'evaluate-measure-subject-list-reporttype'
      description %(Server should properly return subject-list measure report when provided a
      Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject-list"
        measure_evaluation_assert_success('subject-list', :measure_report, params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for population report with required query parameters'
      id 'evaluate-measure-population-reporttype'
      description %(Server should properly return population measure report when provided a
      Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population"
        measure_evaluation_assert_success('summary', :measure_report, params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check proper calculation for population report with Group subject'
      id 'evaluate-measure-population-with-group-subject-reference'
      description %(Server should properly return population measure report when provided a
      Group ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'
      input :group_id, title: 'Group ID'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population&subject=Group/#{group_id}"
        measure_evaluation_assert_success('summary', :measure_report, params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check operation fails for invalid measure ID'
      id 'evaluate-measure-invalid-measureid'
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
      id 'evaluate-measure-invalid-patientid'
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
      id 'evaluate-measure-missing-period-start'
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
      id 'evaluate-measure-missing-subject-param'
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
      id 'evaluate-measure-invalid-reporttype'
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
      id 'evaluate-measure-malformed-parameters'
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
      id 'evaluate-measure-missing-periodend'
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
