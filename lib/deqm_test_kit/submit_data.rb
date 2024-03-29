# frozen_string_literal: true

require 'securerandom'
require 'json'

module DEQMTestKit
  # Perform submit data operation on test client
  class SubmitData < Inferno::TestGroup # rubocop:disable Metrics/ClassLength
    # module for shared code for $submit-data assertions and requests
    module SubmitDataHelpers
      def submit_data_assert_failure(params_hash, expected_status: 400)
        params = FHIR::Parameters.new params_hash

        fhir_operation("Measure/#{measure_id}/$submit-data", body: params)
        assert_error(expected_status)
      end

      # rubocop:disable Metrics/MethodLength
      def create_measure_report(measure_url, period_start, period_end)
        mr = {
          'type' => 'data-collection',
          'measure' => measure_url,
          'period' => {
            'start' => period_start,
            'end' => period_end
          },
          'status' => 'complete'
        }
        resource = FHIR::MeasureReport.new(mr)
        resource.identifier = [FHIR::Identifier.new({ value: SecureRandom.uuid })]
        resource
      end
      # rubocop:enable Metrics/MethodLength
    end
    id 'submit_data'
    title 'Submit Data'
    description 'Ensure fhir server can receive data via the $submit-data operation'
    custom_headers = { 'X-Provenance': '{"resourceType": "Provenance", "agent": ["test-agent"]}' }
    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'ColorectalCancerScreeningsFHIR',
                        options: measure_options, title: 'Measure Title' }

    fhir_client do
      url :url
      headers custom_headers
    end

    # rubocop:disable Metrics/BlockLength
    test do
      include SubmitDataHelpers
      title 'Submit Data valid submission'
      id 'submit-data-01'
      description 'Submit resources relevant to a measure, and then verify they persist on the server.'
      makes_request :submit_data
      input :queries_json
      input :measure_id, **measure_id_args
      input :data_requirements_reference_server

      fhir_client :dr_reference_client do
        url :data_requirements_reference_server
      end

      run do
        # get measure from client
        assert(measure_id,
               'No measure selected. Run Measure Availability prior to running the Submit Data test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        measure = resource

        assert_valid_json(queries_json, 'Valid Data Requirements json queries must be used') # for safety
        queries = JSON.parse(queries_json)
        # If we have no queries, get all of these types
        if queries.empty?
          queries = [
            { endpoint: 'Patient', params: {} },
            { endpoint: 'Encounter', params: {} },
            { endpoint: 'Condition', params: {} },
            { endpoint: 'Procedure', params: {} },
            { endpoint: 'Observation', params: {} }
          ]
        end

        # Get submission data
        resources = queries.map do |q|
          # TODO: run query through unlogged rest client
          fhir_search(q['endpoint'], client: :dr_reference_client, params: q['params'])
          code = response[:status]

          # Return all resources in the response bundle if queries are met
          if code == 200
            resource.entry ? resource.entry.map(&:resource) : []
          else
            []
          end
        end
        resources.flatten!.uniq!(&:id)

        # Create submit data parameters
        measure_report = create_measure_report(measure.url, '2019-01-01', '2019-12-31')
        params_hash = {
          resourceType: 'Parameters',
          parameter: [{
            name: 'measureReport',
            resource: measure_report

          }]
        }
        params = FHIR::Parameters.new params_hash

        # Add resources to parameters
        resources.each do |r|
          # create unique identifier if not present on resource
          r.identifier = [FHIR::Identifier.new({ value: SecureRandom.uuid })] unless r.identifier&.first&.value

          resource_param = {
            name: 'resource',
            resource: r
          }
          params.parameter.push(resource_param)
        end
        # Submit the data
        fhir_operation("Measure/#{measure_id}/$submit-data", body: params, name: :submit_data)
        assert_response_status(200)
        assert_valid_json(response[:body])

        resources.push(measure_report)

        # GET and assert presence of all submitted resources
        resources.each do |r|
          identifier = r.identifier&.first&.value
          assert !identifier.nil?, "Identifier #{identifier} was nil"

          # Search for resource by identifier
          fhir_search(r.resourceType, params: { identifier: })
          assert_response_status(200)
          assert_resource_type(:bundle)
          assert_valid_json(response[:body])
          assert resource.total.positive?,
                 "Search for a #{r.resourceType} with identifier #{identifier} returned no results"
        end
      end
    end

    test do
      include SubmitDataHelpers
      title 'Fails if a measureReport is not submitted'
      id 'submit-data-02'
      description 'Request returns a 400 error if MeasureReport is not submitted.'
      input :measure_id, **measure_id_args
      run do
        test_measure = FHIR::Measure.new(id: measure_id)

        params_hash = {
          resourceType: 'Parameters',
          parameter: [{
            name: 'Measure',
            resource: test_measure
          }]
        }
        submit_data_assert_failure(params_hash)
      end
    end

    test do
      include SubmitDataHelpers
      title 'Fails if multiple measureReports are submitted'
      id 'submit-data-03'
      description 'Request returns a 400 error multiple MeasureReports are not submitted.'
      input :measure_id, **measure_id_args
      run do
        assert(measure_id,
               'No measure selected. Run Measure Availability prior to running the Submit Data test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        measure = resource

        measure_report = create_measure_report(measure.url, '2019-01-01', '2019-12-31')

        params_hash = {
          resourceType: 'Parameters',
          parameter: [{
            name: 'measureReport',
            resource: measure_report
          },
                      {
                        name: 'measureReport',
                        resource: measure_report
                      }]
        }
        submit_data_assert_failure(params_hash)
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
