# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate-measure
  # rubocop:disable Metrics/ClassLength
  class EvaluateMeasure < Inferno::TestGroup
    module MeasureEvaluationTest
      def measure_evaluation_run_block(type, expected_status: 200)
        run do
          fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")
          assert_response_status(expected_status)
          assert_resource_type(:measure_report)
          assert_valid_json(response[:body])
          assert(resource.type == type)
        end
      end
    end
    id 'evaluate_measure'
    title 'Evaluate Measure'
    description 'Ensure FHIR server can calculate a measure'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options }

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
    INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'

    test do
      extend MeasureEvaluationTest
      title 'Check $evaluate-measure proper calculation for individual report with required query parameters'
      id 'evaluate-measure-01'
      description %(Server should properly return an individual measure report when provided a
        Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        # fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        # assert_response_status(200)
        # assert_resource_type(:measure_report)
        # assert_valid_json(response[:body])
        # assert(resource.type == 'individual')
        measure_evaluation_run_block('individual')

      end
    end

    # NOTE: this test will fail for deqm-test-server
    test do
      title 'Check $evaluate-measure proper calculation for subject-list report with required query parameters'
      id 'evaluate-measure-02'
      description %(Server should properly return subject-list measure report when provided a
      Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject-list"
        # fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        # assert_response_status(200)
        # assert_resource_type(:measure_report)
        # assert_valid_json(response[:body])
        # assert(resource.type == 'subject-list')
        measure_evaluation_run_block('subject-list')

      end
    end

    test do
      title 'Check $evaluate-measure proper calculation for population report with required query parameters'
      id 'evaluate-measure-03'
      description %(Server should properly return population measure report when provided a
      Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        # assert_response_status(200)
        # assert_resource_type(:measure_report)
        # assert_valid_json(response[:body])
        # assert(resource.type == 'summary')
        measure_evaluation_run_block('summary')

      end
    end
    test do
      title 'Check $evaluate-measure proper calculation for population report with Group subject'
      id 'evaluate-measure-04'
      description %(Server should properly return population measure report when provided a
      Group ID and required query parameters \(period start, period end\).)
      input :measure_id, measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'
      input :group_id, title: 'Group ID'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population&subject=Group/#{group_id}"
        # fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        # assert_response_status(200)
        # assert_resource_type(:measure_report)
        # assert_valid_json(response[:body])
        # assert(resource.type == 'summary')
        measure_evaluation_run_block('summary')

      end
    end
    test do
      title 'Check $evaluate-measure fails for invalid measure ID'
      id 'evaluate-measure-05'
      description 'Request returns a 404 error when the given measure ID cannot be found.'
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        fhir_operation("/Measure/#{INVALID_MEASURE_ID}/$evaluate-measure?#{params}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for invalid patient ID'
      id 'evaluate-measure-06'
      description 'Request returns a 404 error when the given patient ID cannot be found'
      input :measure_id, measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for missing required query parameter'
      id 'evaluate-measure-07'
      description %(Server should not perform calculation and return a 400 response code
    when one of the required query parameters is omitted from the request. In this test,
      the measurement period start is omitted from the request.)
      input :measure_id, measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for missing subject query parameter (individual report type)'
      id 'evaluate-measure-08'
      description %(Server should not perform calculation and return a 400 response code
    when the individual report type is specified but no subject has been specified in the
      query parameters.)
      input :measure_id, measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for invalid reportType'
      id 'evaluate-measure-09'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" \
                 "&reportType=#{INVALID_REPORT_TYPE}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
