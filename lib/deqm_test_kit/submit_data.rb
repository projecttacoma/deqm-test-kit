# frozen_string_literal: true

require 'byebug'
require 'securerandom'

module DEQMTestKit
  # Perform submit data operation on test client
  class SubmitData < Inferno::TestGroup
    id 'submit_data'
    title 'Submit Data'
    description 'Ensure fhir server can receive data via the $submit-data operation'

    fhir_client do
      url :url
    end

    fhir_client :embedded_client do
      url 'http://cqf_ruler:8080/cqf-ruler-r4/fhir'
    end

    # rubocop:disable Metrics/BlockLength
    test do
      title 'Submit Data valid submission'
      id 'submit-data-01'
      description 'Submit resources relevant to a measure, and then verify they persist on the server.'
      makes_request :submit_data
      input :queries_json
      input :measure_id

      run do
        # get measure from client
        assert(measure_id,
               'No measure selected. You must run the Measure Availability test group prior to running the Submit Data test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        measure = JSON.parse(response[:body])

        assert_valid_json(queries_json, 'Valid json queries must be passed from the Data Requirements test group') # for safety
        queries = JSON.parse(queries_json)
        # If we have no queries, get all of these types
        if queries.empty?
          queries = [
            { 'endpoint' => 'Patient', 'params' => {} },
            { 'endpoint' => 'Encounter', 'params' => {} },
            { 'endpoint' => 'Condition', 'params' => {} },
            { 'endpoint' => 'Procedure', 'params' => {} },
            { 'endpoint' => 'Observation', 'params' => {} }
          ]
        end
        # Call the $updateCodeSystems workaround on embedded cqf-ruler so code:in queries work
        fhir_operation('$updateCodeSystems', client: :embedded_client)
        reply = fhir_client(:embedded_client).send(:get, "$updateCodeSystems")
        assert reply.response[:code] == 200

        # Get submission data
        resources = queries.map do |q|
          # TODO: run query through unlogged rest client
          fhir_search(q['endpoint'], client: :embedded_client, params: q['params'])
          code = response[:status]

          # Return all resources in the response bundle if queries are met
          if code == 200
            bundle = JSON.parse(response[:body])
            bundle['entry'] ? bundle['entry'].map { |e| e['resource'] } : []
          else
            []
          end
        end.flatten.uniq { |r| r['id'] }

        # Create submit data parameters
        measure_report = create_measure_report(measure['url'], '2019-01-01', '2019-12-31')
        params = {
          resourceType: 'Parameters',
          parameter: [{
            name: 'measureReport',
            resource: measure_report
          }]
        }

        # Add resources to parameters
        resources.each do |r|
          # create unique identifier if not present on resource
          unless r.dig('identifier')&.first&.dig('value')
            r['identifier'] = [{}]
            r['identifier'][0]['value'] = SecureRandom.uuid
          end

          resource_param = {
            name: 'resource',
            resource: r
          }
          params[:parameter].push(resource_param)
        end
        # Submit the data
        fhir_operation("Measure/#{measure_id}/$submit-data", body: params, name: :submit_data)
        assert_response_status(200)
        assert_valid_json(response[:body])

        resources.push(measure_report)

        # GET and assert presence of all submitted resources
        resources.each do |r|
          identifier = r.dig('identifier')&.first&.dig('value')
          assert !identifier.nil?, "Identifier #{identifier} was nil"

          # Search for resource by identifier
          fhir_search(r['resourceType'], params: { identifier: identifier })
          assert_response_status(200)
          assert_resource_type(:bundle)
          assert_valid_json(response[:body])
          resource_bundle = JSON.parse(response[:body])
          assert resource_bundle['total'].positive?,
                 "Search for a #{r['resourceType']} with identifier #{identifier} returned no results"
        end
      end
    end

    def create_measure_report(measure_url, period_start, period_end)
       mr = {
        resourceType: 'MeasureReport',
        type: 'data-collection',
        measure: measure_url,
        period: {
          start: period_start,
          end: period_end
        },
        status: 'complete'
      }
      mr['identifier'] = [{}]
      mr['identifier'][0]['value'] = SecureRandom.uuid
      mr
    end
  end
  # rubocop:enable Metrics/BlockLength
end
