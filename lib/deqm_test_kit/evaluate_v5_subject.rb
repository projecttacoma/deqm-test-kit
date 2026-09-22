# frozen_string_literal: true

require 'json'
require_relative '../utils/evaluate_utils'

module DEQMTestKit
  # tests for $evaluate subject (DEQM v5.0.0)
  # rubocop:disable Metrics/ClassLength
  class EvaluateSubject < Inferno::TestGroup
    id :evaluate_v5_subject
    description 'Ensure FHIR server can calculate a measure using $evaluate operation with subject (DEQM v5.0.0)'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
      auth_info :deqm_smart_auth_info
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    additional_measure_options = JSON.parse(File.read('./lib/fixtures/measureCheckBoxes.json'))
    measure_id_args = {
      type: 'radio',
      optional: false,
      default: 'ColorectalCancerScreeningsFHIR',
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

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
    INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'
    INVALID_START_DATE = 'INVALID_START_DATE'

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=subject and Patient subject'
      id 'evaluate-subject-patient'
      description %(Measure/$evaluate with reportType=subject and Patient subject returns
      200 and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: selected_measure_id
            },
            {
              name: 'subject',
              valueString: patient_id
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
        result = fhir_operation('/Measure/$evaluate', body:)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_measurereport_bundles(parameters)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with multiple measureIds and reportType=subject and Patient subject'
      id 'evaluate-multiple-measure-subject-patient'
      description %(Measure/$evaluate with multiple measureIds and reportType=subject and subject Patient
      returns 200 and FHIR Parameters resource.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :additional_measures, **additional_measures_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        measure_ids = [selected_measure_id]
        measure_ids += additional_measures if additional_measures&.any?

        measure_params = measure_ids.map { |id| { name: 'measureId', valueString: id } }
        patient_param = { name: 'subject', valueString: patient_id }

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
          ].concat(measure_params).push(patient_param)
        }
        fhir_operation('/Measure/$evaluate', body:)

        assert_response_status(200)

        assert resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{resource&.class}"

        validate_parameters_contains_measurereport_bundles(resource)

        # Verify we have the expected number of bundles for each subject
        assert resource.parameter.length == 1,
               "Expected 1 Bundle for reportType=subject and 1 patient specified, got #{resource.parameter.length}"

        expected_measure_report_count = measure_ids.length
        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == expected_measure_report_count,
               "Expected 1 MeasureReport, got #{measure_reports.length}"
      end
    end

    # POPULATION
    # GROUP REFERENCE
    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=population and subject Group reference'
      id 'evaluate-subject-group-reference-population'
      description %(Measure/$evaluate with reportType=population and subject Group reference.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :group_id, title: 'Group ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'subject',
              valueString: "Group/#{group_id}"
            },
            {
              name: 'measureId',
              valueString: selected_measure_id
            },
            {
              name: 'reportType',
              valueString: 'population'
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
        fhir_operation('/Measure/$evaluate', body:)

        assert_response_status(200)

        assert resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{resource&.class}"

        validate_parameters_contains_measurereport_bundles(resource)

        # Verify we have the expected number of bundles for each subject
        assert resource.parameter.length == 1,
               "Expected 1 Bundle, got #{resource.parameter.length}"

        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == 1,
               "Expected 1 MeasureReport, got #{measure_reports.length}"
      end
    end

    # SUBJECT
    # GROUP REFERENCE
    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=subject and subject Group reference'
      id 'evaluate-subject-group-reference-subject'
      description %(Measure/$evaluate with reportType=subject and subject Group reference.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :group_id, title: 'Group ID'
      input :group_subjects, title: 'Number of subjects in the provided Group'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'subject',
              valueString: "Group/#{group_id}"
            },
            {
              name: 'measureId',
              valueString: selected_measure_id
            },
            {
              name: 'reportType',
              valueString: 'subject'
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
        fhir_operation('/Measure/$evaluate', body:)

        assert_response_status(200)

        assert resource.is_a?(FHIR::Parameters),
               "Expected resource to be a Parameters resource, but got #{resource&.class}"

        validate_parameters_contains_measurereport_bundles(resource)

        # Verify we have the expected number of bundles for each subject
        assert resource.parameter.length.to_s == group_subjects,
               "Expected #{group_subjects} Bundles for each subject specified in the referenced Group,
                got #{resource.parameter.length}"

        resource.parameter.each do |param|
          measure_reports = param.resource.entry.select { |entry| entry.resource.resourceType == 'MeasureReport' }
          assert measure_reports.length == 1, "Expected 1 MeasureReport in each Bundle, got #{measure_reports.length}"
        end
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate reportType=subject fails for invalid measure ID'
      id 'evaluate-invalid-measureid-subject'
      description 'Request returns a 404 error when the given measure ID cannot be found.'
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: INVALID_MEASURE_ID
            },
            {
              name: 'subject',
              valueString: patient_id
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
        fhir_operation('/Measure/$evaluate', body:)
        assert_error(404)
      end
    end

    test do
      include EvaluateUtils

      title 'Measure/[id]/$evaluate reportType=subject fails for invalid measure ID'
      id 'evaluate-measureid-path-invalid-measureid'
      description 'Request returns a 404 error when the given measure ID cannot be found.'
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, INVALID_MEASURE_ID, expected_status: 404)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate reportType=subject fails for invalid patient ID'
      id 'evaluate-invalid-patientid-subject-body'
      description 'Request returns a 404 error when the given patient ID cannot be found.'
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: selected_measure_id
            },
            {
              name: 'subject',
              valueString: INVALID_PATIENT_ID
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
        fhir_operation('/Measure/$evaluate', body:)
        assert_error(404)
      end
    end

    test do
      include EvaluateUtils

      title 'Measure/[id]/$evaluate reportType=subject fails for invalid patient ID'
      id 'evaluate-measureid-path-invalid-patientid'
      description 'Request returns a 404 error when the given patient ID cannot be found'
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
        measure_evaluation_assert_failure(params, selected_measure_id, expected_status: 404)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate reportType=subject fails for invalid reportType'
      id 'evaluate-body-invalid-reporttype'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: selected_measure_id
            },
            {
              name: 'subject',
              valueString: patient_id
            },
            {
              name: 'periodStart',
              valueDate: period_start
            },
            {
              name: 'periodEnd',
              valueDate: period_end
            },
            {
              name: 'reportType',
              valueString: INVALID_REPORT_TYPE
            }
          ]
        }
        fhir_operation('/Measure/$evaluate', body:)
        assert_error(400)
      end
    end

    test do
      include EvaluateUtils

      title 'Measure/[id]/$evaluate reportType=subject fails for invalid reportType'
      id 'evaluate-measureid-path-invalid-reporttype'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" \
                 "&reportType=#{INVALID_REPORT_TYPE}"
        measure_evaluation_assert_failure(params, selected_measure_id)
      end
    end

    test do
      include EvaluateUtils

      title 'Measure/[id]/$evaluate reportType=subject fails for missing subject query parameter'
      id 'evaluate-measureid-path-missing-subject-param'
      description %(Server should not perform calculation and return a 400 response code
      when the subject report type is specified but no subject has been specified in the
      query parameters.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject"
        measure_evaluation_assert_failure(params, selected_measure_id)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate reportType=subject fails for missing periodEnd parameter in the body'
      id 'evaluate-body-missing-periodend'
      description %(Server should return 400 when input is missing periodEnd parameter.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: selected_measure_id
            },
            {
              name: 'subject',
              valueString: patient_id
            },
            {
              name: 'periodStart',
              valueDate: period_start
            }
          ]
        }
        fhir_operation('/Measure/$evaluate', body:)
        assert_error(400)
      end
    end

    test do
      include EvaluateUtils

      title 'Measure/[id]/$evaluate reportType=subject fails for missing periodEnd parameter in input'
      id 'evaluate-measureid-path-missing-periodend'
      description %(Server should return 400 when input is missing periodEnd parameter.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'

      run do
        params = "periodStart=#{period_start}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, selected_measure_id, expected_status: 400)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
