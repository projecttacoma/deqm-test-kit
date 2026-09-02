# frozen_string_literal: true

require 'json'
require_relative '../utils/evaluate_utils'

module DEQMTestKit
  # tests for $evaluate subjectGroup (DEQM v5.0.0)
  # rubocop:disable Metrics/ClassLength
  class EvaluateSubjectGroup < Inferno::TestGroup
    id :evaluate_v5_subjectGroup
    description 'Ensure FHIR server can calculate a measure using $evaluate operation with subjectGroup (DEQM v5.0.0)'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
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

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
    INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'
    INVALID_START_DATE = 'INVALID_START_DATE'

    # POPULATION
    # SUBJECTGROUP 2 PATIENTS
    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=population and subjectGroup with 2 Patients'
      id 'evaluate-subject-group-resource-2-patients-population'
      description %(Measure/$evaluate with reportType=population and subjectGroup with 2 Patients.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :patient_id2, title: 'Patient ID 2'
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
              name: 'subjectGroup',
              resource: {
                resourceType: 'Group',
                id: 'test-group-2-subjects',
                member: [
                  {
                    entity: {
                      reference: "Patient/#{patient_id}"
                    }
                  },
                  {
                    entity: {
                      reference: "Patient/#{patient_id2}"
                    }
                  }
                ]
              }
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
               "Expected 1 Bundle for 2 patients specified in subjectGroup for reportType=population,
               got #{resource.parameter.length}"

        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == 1,
               "Expected 1 MeasureReport, got #{measure_reports.length}"
      end
    end

    # SUBJECT
    # SUBJECTGROUP 2 PATIENTS
    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=subject and subjectGroup with 2 Patients'
      id 'evaluate-subject-group-resource-2-patients-subject'
      description %(Measure/$evaluate with reportType=subject and subjectGroup with 2 Patients.)
      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :patient_id, title: 'Patient ID'
      input :patient_id2, title: 'Patient ID 2'
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
              name: 'subjectGroup',
              resource: {
                resourceType: 'Group',
                id: 'test-group-2-subjects',
                member: [
                  {
                    entity: {
                      reference: "Patient/#{patient_id}"
                    }
                  },
                  {
                    entity: {
                      reference: "Patient/#{patient_id2}"
                    }
                  }
                ]
              }
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
        assert resource.parameter.length == 2,
               "Expected 2 Bundles for 2 patients specified in subjectGroup, got #{resource.parameter.length}"

        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == 1,
               "Expected 1 MeasureReport, got #{measure_reports.length}"
      end
    end

    # POPULATION
    # SUBJECTGROUP 1 PATIENT
    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=population and subjectGroup with 1 Patient'
      id 'evaluate-subject-group-resource-1-patient-population'
      description %(Measure/$evaluate with reportType=population and subjectGroup with 1 Patient.)
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
               "Expected 1 Bundle for reportType=population with 1 patient specified in subjectGroup,
                got #{resource.parameter.length}"

        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == 1,
               "Expected 1 MeasureReport, got #{measure_reports.length}"
      end
    end

    # SUBJECT
    # SUBJECTGROUP 1 PATIENT
    test do # rubocop:disable Metrics/BlockLength
      include EvaluateUtils

      title 'Measure/$evaluate with reportType=subject and subjectGroup with 1 Patient'
      id 'evaluate-subject-group-resource-1-patient-subject'
      description %(Measure/$evaluate with reportType=subject and subjectGroup with 1 Patient.)
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
        assert resource.parameter.length == 1,
               "Expected 1 Bundle for reportType=subject and 1 patient specified in subjectGroup,
                got #{resource.parameter.length}"

        measure_reports = resource.parameter[0].resource.entry.select do |entry|
          entry.resource.resourceType == 'MeasureReport'
        end
        assert measure_reports.length == 1,
               "Expected 1 MeasureReport, got #{measure_reports.length}"
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
