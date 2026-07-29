# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # Helpers shared by $collect-data specs
  module CollectDataSpecUtils
    def create_parameters_response(measure_urls:)
      measure_reports = measure_urls.map do |url|
        FHIR::MeasureReport.new(
          status: 'complete', type: 'data-collection',
          measure: url,
          period: { start: '2019-01-01', end: '2019-12-31' }
        )
      end
      bundle = FHIR::Bundle.new(type: 'transaction', entry: measure_reports.map { |mr| { resource: mr } })

      FHIR::Parameters.new(parameter: { name: 'return', resource: bundle })
    end

    # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
    def create_parameters_request(measure_urls:, period_start:, period_end:, patient_id: nil, patient_id_list: nil,
                                  data_endpoint: nil)
      parameters = measure_urls.map { |measure_url| { name: 'measureUrl', valueCanonical: measure_url } }
      parameters << { name: 'subject', valueString: "Patient/#{patient_id}" } if patient_id
      if patient_id_list
        parameters << {
          name: 'subjectGroup',
          resource: {
            resourceType: 'Group',
            id: 'test-group-subjectGroup',
            member: patient_id_list.map { |group_patient_id| { entity: { reference: "Patient/#{group_patient_id}" } } }
          }
        }
      end
      parameters << { name: 'periodStart', valueDate: period_start }
      parameters << { name: 'periodEnd', valueDate: period_end }
      parameters << { name: 'dataEndpoint', resource: JSON.parse(data_endpoint) } if data_endpoint

      {
        resourceType: 'Parameters',
        parameter: parameters
      }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

    def run(runnable, inputs = {})
      test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
      test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
      inputs.each do |name, value|
        session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
      end
      Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
    end
  end
end
