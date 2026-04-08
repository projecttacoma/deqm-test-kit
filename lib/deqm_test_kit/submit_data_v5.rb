# frozen_string_literal: true

require 'securerandom'
require 'json'

module DEQMTestKit
  # Perform submit data operation on test client
  class SubmitDataV5 < Inferno::TestGroup
    # module for shared code for $submit-data assertions and requests
    module SubmitDataHelpers
      def create_data_exchange_measure_report(measure_canonical, period_start, period_end, subject_id) # rubocop:disable Metrics/MethodLength
        mr_hash = {
          'resourceType' => 'MeasureReport',
          'id' => SecureRandom.uuid,
          'measure' => measure_canonical,
          'period' => { 'start' => period_start, 'end' => period_end },
          'status' => 'complete',
          'type' => 'data-collection',
          'subject' => { 'reference' => "Patient/#{subject_id}" },
          'date' => Time.now.utc.strftime('%Y-%m-%d'),
          'meta' => {
            'profile' => ['http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/datax-measurereport-deqm']
          },
          'extension' => [
            {
              'url' => 'http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/extension-submitDataUpdateType',
              'valueCode' => 'snapshot'
            }
          ],
          'contained' => [
            { 'resourceType' => 'Organization', 'id' => 'inferno-testkit' }
          ],
          'reporter' => { 'reference' => 'Organization/inferno-testkit' }
        }
        FHIR::MeasureReport.new(mr_hash)
      end

      def create_patient(given_name)
        FHIR::Patient.new(
          'id' => "pat-#{SecureRandom.uuid}",
          'name' => [{ 'family' => 'Test', 'given' => [given_name] }]
        )
      end

      def create_encounter(patient_id)
        FHIR::Encounter.new(
          'id' => "enc-#{SecureRandom.uuid}",
          'identifier' => [{ 'value' => SecureRandom.uuid }],
          'status' => 'finished',
          'class' => { 'system' => 'http://terminology.hl7.org/CodeSystem/v3-ActCode', 'code' => 'AMB' },
          'subject' => { 'reference' => "Patient/#{patient_id}" },
          'period' => { 'start' => '2019-06-01', 'end' => '2019-06-02' }
        )
      end

      def create_submit_bundle(measure_reports, patient, encounter) # rubocop:disable Metrics/MethodLength
        entries = measure_reports.map do |mr|
          { 'resource' => mr.to_hash, 'request' => { method: 'PUT', url: "MeasureReport/#{mr.id}" } }
        end
        FHIR::Bundle.new(
          'type' => 'transaction',
          'entry' => entries.push(
            { 'resource' => patient.to_hash,
              'request' => { method: 'PUT',
                             url: "Patient/#{patient.id}" } }, { 'resource' => encounter.to_hash, 'request' => \
                              { method: 'PUT', url: "Encounter/#{encounter.id}" } }
          )
        )
      end

      def wrap_bundles_in_parameters(*bundles)
        {
          resourceType: 'Parameters',
          parameter: bundles.map { |b| { name: 'bundle', resource: b } }
        }
      end

      def build_measure_reports_for_subject(measure_canonicals, period_start, period_end, subject_id)
        measure_canonicals.map do |mc|
          create_data_exchange_measure_report(mc, period_start, period_end, subject_id)
        end
      end

      def validate_submit_data_output(parameters)
        assert_resource_type(FHIR::Parameters, resource: parameters)
        assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array' # this may not be needed because of the above validation # rubocop:disable Layout/LineLength

        parameters.parameter.each do |param|
          assert_resource_type(FHIR::Bundle, resource: param.resource)
          assert param.resource.type == 'transaction-response',
                 'Expected Bundles contained in the Parameters resource to be of type "transaction-response"'
        end
      end
    end

    id 'submit_data_v5'
    title '$submit-data-v5'
    description 'Ensure fhir server can receive data via the $submit-data operation'
    provenance = {
      resourceType: 'Provenance',
      agent: [
        {
          who: {
            reference: 'Practitioner/test-agent',
            type: 'Practitioner'
          }
        }
      ]
    }
    custom_headers = {
      'X-Provenance' => provenance.to_json
    }

    input :measure_url_list,
          title: 'Measures (comma-separated URLs with versions)',
          type: 'text',
          description: 'Example: http://example.org/Measure/A|1.0.0,http://example.org/Measure/B|1.2.3'

    input :period_start, title: 'Measurement period start', default: '2026-01-01'
    input :period_end, title: 'Measurement period end', default: '2026-12-31'

    fhir_client do
      url :url
      headers custom_headers
    end

    test do
      include SubmitDataHelpers
      title 'Submit Data valid submission (one subject, multiple measures)'
      id 'submit-data-valid-one-subject-multi-measures'
      description 'Submit a Parameters resource containing a single Bundle with one Patient, one Encounter, ' \
                  'and a data-collection MeasureReport per requested measure.'

      run do
        measures = measure_url_list.split(',')

        patient = create_patient('Patient1')
        encounter = create_encounter(patient.id)

        reports = build_measure_reports_for_subject(measures, period_start, period_end, patient.id)

        bundle = create_submit_bundle(reports, patient, encounter)

        # Wrap bundles in a Parameters resource
        params_hash = wrap_bundles_in_parameters(bundle)
        params = FHIR::Parameters.new(params_hash)

        # $submit-data operation with passed in FHIR Parameters resource we created
        fhir_operation('Measure/$submit-data', body: params)
        assert_response_status(200)
        validate_submit_data_output(resource)
      end
    end

    test do
      include SubmitDataHelpers
      title 'Submit Data valid submission (two subjects, multiple measures each)'
      id 'submit-data-valid-two-subjects-multi-measures'
      description 'Submit a Parameters resource containing two Bundles, each organized by subject, ' \
                  'with data-collection MeasureReport(s) for the requested measures.'

      run do
        measures = measure_url_list.split(',')

        # Subject 1
        patient1 = create_patient('Patient1')
        encounter1 = create_encounter(patient1.id)
        reports1 = build_measure_reports_for_subject(measures, period_start, period_end, patient1.id)
        bundle1 = create_submit_bundle(reports1, patient1, encounter1)

        # Subject 2
        patient2 = create_patient('Patient2')
        encounter2 = create_encounter(patient2.id)
        reports2 = build_measure_reports_for_subject(measures, period_start, period_end, patient2.id)
        bundle2 = create_submit_bundle(reports2, patient2, encounter2)

        # Wrap bundles in a Parameters resource
        params_hash = wrap_bundles_in_parameters(bundle1, bundle2)
        params = FHIR::Parameters.new(params_hash)

        # $submit-data operation with passed in FHIR Parameters resource we created
        fhir_operation('Measure/$submit-data', body: params)
        assert_response_status(200)
        validate_submit_data_output(resource)
      end
    end
  end
end
