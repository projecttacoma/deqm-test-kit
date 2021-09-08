module DEQMTestKit

    #GET [base]/Measure/CMS146/$data-requirements?periodStart=2014&periodEnd=2014
    class DataRequirements < Inferno::TestGroup
      id 'data_requirements'
      title 'Data Requirements'
      description 'Ensure fhir server can respond to the $data-requirements request'
  
      fhir_client do
        url :url
      end
  
      test do
        title 'Check data requirements against expected return'
        id 'data-requirements-01'
        description 'Data requirements on the fhir test server match the data requirements of our embedded client'
        makes_request :data_requirements
  
        run do
          # Look for matching measure from cqf-ruler datastore by resource id
          # TODO: actually pull measure from user input drop down (populated from embedded client)
          measure_to_test = 'EXM130|7.3.000'
          measure_identifier, measure_version = measure_to_test.split('|')
  
          # @client.additional_headers = { 'x-api-key': @instance.api_key, 'Authorization': @instance.auth_header } if @instance.api_key && @instance.auth_header
  
          # Search system for measure by identifier and version
          fhir_search(:measure, params: { name: measure_identifier, version: measure_version }, name: :measure_search)
          measure_bundle = JSON.parse(response[:body])
          id = measure_bundle.entry[0].resource.id;
          fhir_operation("Measure/#{id}/$data-requirements", name: :data_requirements)
          assert_response_status(200)
          assert_resource_type(:measure)
          assert_valid_json(response[:body])

        end
      end
    end
  end