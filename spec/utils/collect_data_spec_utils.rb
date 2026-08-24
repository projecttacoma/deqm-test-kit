# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # Helpers shared by $collect-data specs
  module CollectDataSpecUtils
    # rubocop:disable Metrics/MethodLength
    def create_parameters_response(measure_urls: nil, measure_ids: nil, bundle_count: 1)
      measures = measure_ids || measure_urls
      measure_reports = measures.map do |measure|
        FHIR::MeasureReport.new(
          status: 'complete', type: 'data-collection',
          measure: measure,
          period: { start: '2019-01-01', end: '2019-12-31' }
        )
      end

      bundles = bundle_count.times.map do
        FHIR::Bundle.new(type: 'transaction', entry: measure_reports.map { |mr| { resource: mr } })
      end

      FHIR::Parameters.new(
        parameter: bundles.map { |bundle| FHIR::Parameters::Parameter.new(name: 'return', resource: bundle) }
      )
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def create_parameters_request(options)
      measure_name, measure_value_name, measures =
        if options[:measure_ids]
          ['measureId', :valueId, options[:measure_ids]]
        else
          ['measureUrl', :valueCanonical, options[:measure_urls]]
        end
      parameters = measures.map do |measure|
        { name: measure_name, measure_value_name => measure }
      end
      parameters << { name: 'subject', valueString: "Patient/#{options[:patient_id]}" } if options[:patient_id]
      if options[:patient_id_list]
        parameters << {
          name: 'subjectGroup',
          resource: {
            resourceType: 'Group',
            id: 'test-group-subjectGroup',
            type: 'person',
            actual: true,
            member: options[:patient_id_list].map do |patient_id|
              { entity: { reference: "Patient/#{patient_id}" } }
            end
          }
        }
      end
      parameters << { name: 'periodStart', valueDate: options[:period_start] }
      parameters << { name: 'periodEnd', valueDate: options[:period_end] }
      parameters << { name: 'dataEndpoint', resource: JSON.parse(options[:data_endpoint]) } if options[:data_endpoint]

      {
        resourceType: 'Parameters',
        parameter: parameters
      }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

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
