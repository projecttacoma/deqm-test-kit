# frozen_string_literal: true

require 'securerandom'

module DEQMTestKit
  # Perform submit data operation on test client
  class SubmitData < Inferno::TestGroup # rubocop:disable Metrics/ClassLength
    id 'submit_data'
    title 'Submit Data'
    description 'Ensure fhir server can receive data via the $submit-data operation'
    custom_headers = { 'X-Provenance': '{"resourceType": "Provenance"}' }

    fhir_client do
      url :url
      headers custom_headers
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
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: {
        list_options: [
          {
            label: 'EXM104',
            value: 'measure-EXM104-8.2.000'
          },
          {
            label: 'EXM105',
            value: 'measure-EXM105-8.2.000'
          },
          {
            label: 'EXM124',
            value: 'measure-EXM124-9.0.000'
          },
          {
            label: 'EXM125',
            value: 'measure-EXM125-7.3.000'
          },
          {
            label: 'EXM130',
            value: 'measure-EXM130-7.3.000'
          }
        ]
      }

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
        # Call the $updateCodeSystems workaround on embedded cqf-ruler so code:in queries work
        fhir_operation('$updateCodeSystems', client: :embedded_client)
        reply = fhir_client(:embedded_client).send(:get, '$updateCodeSystems')
        assert reply.response[:code] == 200

        # Get submission data
        resources = queries.map do |q|
          # TODO: run query through unlogged rest client
          fhir_search(q['endpoint'], client: :embedded_client, params: q['params'])
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
          fhir_search(r.resourceType, params: { identifier: identifier })
          assert_response_status(200)
          assert_resource_type(:bundle)
          assert_valid_json(response[:body])
          assert resource.total.positive?,
                 "Search for a #{r.resourceType} with identifier #{identifier} returned no results"
        end
      end
    end

    test do
      title 'Fails if a measureReport is not submitted'
      id 'submit-data-02'
      description 'Request returns a 400 error if MeasureReport is not submitted.'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: {
        list_options: [
          {
            label: 'EXM104',
            value: 'measure-EXM104-8.2.000'
          },
          {
            label: 'EXM105',
            value: 'measure-EXM105-8.2.000'
          },
          {
            label: 'EXM124',
            value: 'measure-EXM124-9.0.000'
          },
          {
            label: 'EXM125',
            value: 'measure-EXM125-7.3.000'
          },
          {
            label: 'EXM130',
            value: 'measure-EXM130-7.3.000'
          }
        ]
      }
      run do
        test_measure = FHIR::Measure.new(id: measure_id)

        params_hash = {
          resourceType: 'Parameters',
          parameter: [{
            name: 'Measure',
            resource: test_measure
          }]
        }
        params = FHIR::Parameters.new params_hash

        fhir_operation("Measure/#{measure_id}/$submit-data", body: params)

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Fails if multiple measureReports are submitted'
      id 'submit-data-03'
      description 'Request returns a 400 error multiple MeasureReports are not submitted.'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: {
        list_options: [
          {
            label: 'EXM104',
            value: 'measure-EXM104-8.2.000'
          },
          {
            label: 'EXM105',
            value: 'measure-EXM105-8.2.000'
          },
          {
            label: 'EXM124',
            value: 'measure-EXM124-9.0.000'
          },
          {
            label: 'EXM125',
            value: 'measure-EXM125-7.3.000'
          },
          {
            label: 'EXM130',
            value: 'measure-EXM130-7.3.000'
          }
        ]
      }
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
        params = FHIR::Parameters.new params_hash

        fhir_operation("Measure/#{measure_id}/$submit-data", body: params)

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    # rubocop:enable Metrics/BlockLength
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
end
