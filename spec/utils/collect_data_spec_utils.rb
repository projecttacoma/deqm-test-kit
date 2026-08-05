# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # Helpers shared by $collect-data specs
  module CollectDataSpecUtils
    # rubocop:disable Metrics/MethodLength
    def create_parameters_response(measure_urls:, bundle_count: 1)
      measure_reports = measure_urls.map do |url|
        FHIR::MeasureReport.new(
          status: 'complete', type: 'data-collection',
          measure: url,
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
      parameters = options[:measure_urls].map do |measure_url|
        { name: 'measureUrl', valueCanonical: measure_url }
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
