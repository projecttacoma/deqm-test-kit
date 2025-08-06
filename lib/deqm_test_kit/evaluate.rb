# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate (DEQM v5.0.0)
  # rubocop:disable Metrics/ClassLength
  class Evaluate < Inferno::TestGroup
    # module for shared code for $evaluate assertions and requests
    module MeasureEvaluationHelpers
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
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
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

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/[id]/$evaluate (default reportType=population)'
      id 'evaluate-measureid-path-default-reporttype'
      description %(Measure/[id]/$evaluate without reportType (defaults to reportType=population)
      returns 200 and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

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
          ]
        }
        result = fhir_operation("/Measure/#{measure_id}/$evaluate", body:)
        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource
        validate_parameters_contains_measurereport_bundles(parameters)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate with measureId in Parameters resource request body without reportType (defaults to reportType=population)' # rubocop:disable Layout/LineLength
      id 'evaluate-measureid-body-default-reporttype'
      description %(Measure/$evaluate with measureId in Parameters resource request body and
      without reportType (defaults to reportType=population) returns 200 and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: measure_id
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
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate with reportType=subject and measureId in Parameters resource request body'
      id 'evaluate-subject-reporttype-body'
      description %(Measure/$evaluate with reportType=subject and subject and measureId in Parameters resource request
      body returns 200 and FHIR Parameters resource.)

      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: measure_id
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
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate with multiple measureIds in Parameters resource request body without reportType (defaults to reportType=population)' # rubocop:disable Layout/LineLength
      id 'evaluate-multiple-measureids-default-reporttype'
      description %(Measure/$evaluate without reportType (defaults to reportType=population) and subject and multiple
      measureIds in Parameters resource request body returns 200 and FHIR Parameters resource.)
      input :measure_id, **measure_id_args
      input :additional_measures, **additional_measures_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        measure_ids = [measure_id]
        measure_ids += additional_measures if additional_measures&.any?

        measure_params = measure_ids.map { |id| { name: 'measureId', valueString: id } }

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
          ].concat(measure_params)
        }
        fhir_operation('/Measure/$evaluate', body:)

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

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate with reportType=subject and multiple measureIds in Parameters resource request body'
      id 'evaluate-multiple-measureids-with-subject'
      description %(Measure/$evaluate with reportType=subject and subject and multiple measureIds in Parameters
      resource request body returns 200 and FHIR Parameters resource.)
      input :measure_id, **measure_id_args
      input :additional_measures, **additional_measures_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        measure_ids = [measure_id]
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

        # Verify we have the expected number of bundles for each measure
        expected_bundle_count = measure_ids.length
        assert resource.parameter[0].resource.entry.length >= expected_bundle_count,
               "Expected at #{expected_bundle_count} bundles, got #{resource.parameter[0].resource.entry.length}"
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate with reportType=subject and subjectGroup'
      id 'evaluate-subjectgroup-embedded-resource'
      description %(Measure/$evaluate with reportType=subject and subjectGroup.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'
      input :patient_id, title: 'Patient ID'
      input :group_id, title: 'Group ID'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: measure_id
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
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate with reportType=subject and subject Group reference'
      id 'evaluate-subjectgroup-reference'
      description %(Measure/$evaluate with reportType=subject and subject Group reference.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'
      input :group_id, title: 'Group ID'

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
              valueString: measure_id
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
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
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
      include MeasureEvaluationHelpers
      title 'Measure/[id]/$evaluate fails for invalid measure ID'
      id 'evaluate-measureid-query-invalid-measureid'
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
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate reportType=subject fails for invalid patient ID'
      id 'evaluate-invalid-patientid-subject-body'
      description 'Request returns a 404 error when the given patient ID cannot be found.'
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: measure_id
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
      include MeasureEvaluationHelpers
      title 'Measure/[id]/$evaluate reportType=subject fails for invalid patient ID'
      id 'evaluate-measureid-query-invalid-patientid'
      description 'Request returns a 404 error when the given patient ID cannot be found'
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
        measure_evaluation_assert_failure(params, measure_id, expected_status: 404)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Measure/[id]/$evaluate fails for missing subject query parameter (subject report type)'
      id 'evaluate-missing-subject-param'
      description %(Server should not perform calculation and return a 400 response code
      when the subject report type is specified but no subject has been specified in the
      query parameters.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Measure/[id]/$evaluate reportType=subject fails for invalid reportType'
      id 'evaluate-measureid-query-invalid-reporttype'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" \
                 "&reportType=#{INVALID_REPORT_TYPE}"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate reportType=subject fails for invalid reportType'
      id 'evaluate-body-invalid-reporttype'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'
      input :period_end, title: 'Measurement period end', default: '2026-12-31'

      run do # rubocop:disable Metrics/BlockLength
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: measure_id
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
      include MeasureEvaluationHelpers
      title 'Measure/[id]/$evaluate reportType=subject fails for missing periodEnd parameter in input'
      id 'evaluate-measureid-query-missing-periodend'
      description %(Server should return 400 when input is missing periodEnd parameter.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'

      run do
        params = "periodStart=#{period_start}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include MeasureEvaluationHelpers
      title 'Measure/$evaluate reportType=subject fails for missing periodEnd parameter in the body'
      id 'evaluate-body-missing-periodend'
      description %(Server should return 400 when input is missing periodEnd parameter.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2026-01-01'

      run do
        body = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureId',
              valueString: measure_id
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
  end
  # rubocop:enable Metrics/ClassLength
end
