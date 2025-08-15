# frozen_string_literal: true

require 'securerandom'
require 'json'

module DEQMTestKit
  # Perform submit data operation on test client
  class SubmitDataV5 < Inferno::TestGroup
    # module for shared code for $submit-data assertions and requests
    module SubmitDataHelpers # rubocop:disable Metrics/ModuleLength
      def canonical_measure(measure_url, measure_version)
        return measure_url if measure_url&.include?('|') || measure_version.nil? || measure_version.strip.empty?

        "#{measure_url}|#{measure_version}"
      end

      # DELETEME: Based off of fqm-testify
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
            # TODO: Check what sort of organization we should be using here?
            { 'resourceType' => 'Organization', 'id' => 'inferno-testkit' }
          ],
          'reporter' => { 'reference' => 'Organization/inferno-testkit' }
        }
        FHIR::MeasureReport.new(mr_hash)
      end

      def create_dummy_patient
        FHIR::Patient.new(
          'id' => "pat-#{SecureRandom.uuid}",
          'identifier' => [{ 'value' => SecureRandom.uuid }],
          'name' => [{ 'family' => 'Test', 'given' => ['Patient'] }]
        )
      end

      def create_dummy_encounter(patient_id)
        FHIR::Encounter.new(
          'id' => "enc-#{SecureRandom.uuid}",
          'identifier' => [{ 'value' => SecureRandom.uuid }],
          'status' => 'finished',
          'class' => { 'system' => 'http://terminology.hl7.org/CodeSystem/v3-ActCode', 'code' => 'AMB' },
          'subject' => { 'reference' => "Patient/#{patient_id}" },
          'period' => { 'start' => '2019-06-01', 'end' => '2019-06-01' }
        )
      end

      # DELETEME: Q Is this the correct way we should be submitting them?
      def create_submit_bundle(measure_report, *resources)
        entries = ([measure_report] + resources).map do |res|
          { 'fullUrl' => "#{res.resourceType}/#{res.id || SecureRandom.uuid}", 'resource' => res.to_hash }
        end
        FHIR::Bundle.new('type' => 'collection', 'id' => "bundle-#{SecureRandom.uuid}", 'entry' => entries)
      end

      # DELETEME: OLD
      # def submit_data_assert_failure(params_hash, expected_status: 400)
      #   params = FHIR::Parameters.new params_hash

      #   fhir_operation("Measure/#{selected_measure_id}/$submit-data", body: params)
      #   assert_error(expected_status)
      # end

      def wrap_bundles_in_parameters(*bundles)
        {
          resourceType: 'Parameters',
          parameter: bundles.map { |b| { name: 'bundle', resource: b } }
        }
      end

      def validate_parameters_contains_bundles_with_data_collection_reports(parameters)
        assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
        assert parameters.parameter.any?, 'Expected at least one parameter entry in Parameters resource'

        parameters.parameter.each do |param|
          assert param.name == 'bundle', 'Expected parameter.name to be "bundle"'
          assert param.resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
          validate_bundle_contains_data_collection_measure_report(param.resource)
        end
      end

      def validate_bundle_contains_data_collection_measure_report(bundle)
        assert bundle.entry.is_a?(Array), 'Expected Bundle.entry to be an array'
        assert bundle.entry.any?, 'Expected at least one entry in Bundle'

        reports = bundle.entry.map(&:resource).select { |res| res.is_a?(FHIR::MeasureReport) }
        assert reports.any?, 'Expected at least one MeasureReport in Bundle'
        reports.each { |r| validate_data_collection_measure_report_fields(r) }
      end

      def validate_data_collection_measure_report_fields(report)
        assert report.status == 'complete', 'Expected MeasureReport.status to be "complete"'
        assert report.type == 'data-collection', 'Expected MeasureReport.type to be "data-collection" for submit-data'
        assert report.measure.present?, 'MeasureReport.measure is missing'
        assert report.period&.start.present?, 'MeasureReport.period.start is missing'
        assert report.period&.end.present?, 'MeasureReport.period.end is missing'
        assert report.subject&.reference.present?, 'MeasureReport.subject is missing'
      end

      def validate_bundle_is_single_subject(bundle)
        subject_refs = bundle.entry
                             .map(&:resource)
                             .select { |res| res.is_a?(FHIR::MeasureReport) }
                             .map { |mr| mr.subject&.reference }
                             .compact
                             .uniq
        assert subject_refs.any?, 'Expected at least one MeasureReport.subject reference in the Bundle'
        assert subject_refs.size == 1,
               "Expected all MeasureReports in Bundle to reference the same subject, got: #{subject_refs}"
      end

      #  For multiple measures if we are taking them in a JSON array
      #  Need to fix this to work with array
      def parse_measures(measures_json, fallback_url, fallback_version)
        list = []
        if measures_json && !measures_json.strip.empty?
          parsed = JSON.parse(measures_json)
          assert parsed.is_a?(Array), 'measures_json must be a JSON array'
          parsed.each do |m|
            assert m['url'].is_a?(String) && !m['url'].empty?, 'Each measure needs a url'
            list << canonical_measure(m['url'], m['version'])
          end
        else
          assert fallback_url && !fallback_url.strip.empty?, 'measure_url is required when measures_json is empty'
          list << canonical_measure(fallback_url, fallback_version)
        end
        list.uniq
      end

      def build_measure_reports_for_subject(measure_canonicals, period_start, period_end, subject_id)
        measure_canonicals.map do |mc|
          create_data_exchange_measure_report(mc, period_start, period_end, subject_id)
        end
      end

      # FOR FALURE TESTS IF WE WANT THEM
      # def submit_data_assert_failure(params_hash, expected_status: 400)
      #   params = FHIR::Parameters.new(params_hash)
      #   fhir_operation('Measure/$submit-data', body: params)
      #   assert_error(expected_status)
      # end
    end
    id 'submit_data_v5'
    title '$submit-data-v5'
    description 'Ensure fhir server can receive data via the $submit-data operation'
    custom_headers = { 'X-Provenance': '{"resourceType": "Provenance", "agent": ["test-agent"]}' }

    input :measure_url, title: 'Measure URL (canonical base)', type: 'text', optional: true
    input :measure_version, title: 'Measure Version (optional)', type: 'text', optional: true
    input :period_start, title: 'Measurement period start', default: '2026-01-01'
    input :period_end, title: 'Measurement period end', default: '2026-12-31'

    fhir_client do
      url :url
      headers custom_headers
    end

    # rubocop:disable Metrics/BlockLength
    test do
      include SubmitDataHelpers
      title 'Submit Data valid submission (one subject, multiple measures)'
      id 'submit-data-valid-one-subject-multi-measures'
      description 'Submit a Parameters resource containing a single Bundle with one Patient, one Encounter, and a data-collection MeasureReport per requested measure.'
      makes_request :submit_data

      # TODO: change this input
      input :measure_url
      input :measure_version
      input :measures_json,
            title: 'Measures (JSON array of {url, version?})',
            type: 'text',
            optional: true,
            description: 'Example: [{"url":"http://example.org/Measure/A","version":"1.0.0"},{"url":"http://example.org/Measure/B"}]'

      run do
        # Need to change this to accept comma sepreated variables ie http://example.org/Measure/A|1.0.0,http://example.org/Measure/B|1.2.3
        measures = parse_measures(measures_json, measure_url, measure_version)

        patient   = create_dummy_patient
        encounter = create_dummy_encounter(patient.id)

        reports   = build_measure_reports_for_subject(measures, period_start, period_end, patient.id)

        bundle = create_submit_bundle(*reports, patient, encounter)

        validate_bundle_contains_data_collection_measure_report(bundle)
        validate_bundle_is_single_subject(bundle)

        params_hash = wrap_bundles_in_parameters(bundle)
        params = FHIR::Parameters.new(params_hash)

        validate_parameters_contains_bundles_with_data_collection_reports(params)

        # Submit
        fhir_operation('Measure/$submit-data', body: params, name: :submit_data)
        assert_response_status(200)
        assert_valid_json(response[:body]) # SUT may return OperationOutcome or similar
      end
    end

    # TODO: Add two subjects and that each have multi measures

    # FALURE TESTS IF WE WANT THEM
    # test do
    #   include SubmitDataHelpers
    #   title 'Fails if no bundle is submitted'
    #   id 'submit-data-fails-missing-bundle'
    #   description 'Request returns a 400 error if no Bundle is provided in Parameters.'
    #   run do
    #     params_hash = { resourceType: 'Parameters', parameter: [] }
    #     submit_data_assert_failure(params_hash)
    #   end
    # end

    # test do
    #   include SubmitDataHelpers
    #   title 'Fails if parameter name is not "bundle"'
    #   id 'submit-data-fails-wrong-parameter-name'
    #   description 'Server should return 400 when the submitted Parameters does not use parameter.name="bundle".'
    #   run do
    #     bogus_bundle = FHIR::Bundle.new('type' => 'collection', 'id' => "bundle-#{SecureRandom.uuid}", 'entry' => [])
    #     params_hash = { resourceType: 'Parameters', parameter: [{ name: 'not-bundle', resource: bogus_bundle }] }
    #     submit_data_assert_failure(params_hash)
    #   end
    # end

    # test do
    #   include SubmitDataHelpers
    #   title 'Fails if bundle contains no MeasureReports'
    #   id 'submit-data-fails-bundle-missing-measurereport'
    #   description 'Each Bundle SHALL contain 1..* DEQM Data Exchange MeasureReports.'
    #   run do
    #     empty_bundle = FHIR::Bundle.new(
    #       'type' => 'collection',
    #       'id' => "bundle-#{SecureRandom.uuid}",
    #       'entry' => [] # no entries at all
    #     )
    #     params_hash = wrap_bundles_in_parameters(empty_bundle)
    #     submit_data_assert_failure(params_hash)
    #   end
    # end

    # test do
    #   include SubmitDataHelpers
    #   title 'Fails if MeasureReport.type != data-collection'
    #   id 'submit-data-fails-measurereport-wrong-type'
    #   description 'Data Exchange MeasureReports in submit-data SHALL use type = data-collection.'
    #   run do
    #     patient   = create_dummy_patient
    #     encounter = create_dummy_encounter(patient.id)

    #     # create a valid MR then mutate the type
    #     mr = create_data_exchange_measure_report('http://example.org/Measure/A|1.0.0', '2019-01-01', '2019-12-31',
    #                                              patient.id)
    #     mr.type = 'population' # violate the SHALL

    #     bundle = create_submit_bundle(mr, patient, encounter)
    #     params_hash = wrap_bundles_in_parameters(bundle)
    #     submit_data_assert_failure(params_hash)
    #   end
    # end

    # rubocop:enable Metrics/BlockLength
  end
end
