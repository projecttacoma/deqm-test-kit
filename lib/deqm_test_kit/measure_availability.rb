module DEQMTestKit
  class MeasureAvailability < Inferno::TestGroup
    id 'measure_availability'
    title 'Measure Availability'
    description 'Ensure selected measures are available on the fhir server'

    fhir_client do
      url :url
    end

    MEASURES = ['EXM130|7.3.000','EXM125|7.3.000']

    test do
      title 'Measure can be found'
      id 'measure-availability-01'
      description 'Selected measure with matching id is available on the server and a valid json object'
      makes_request :measure_search

      run do
        # Look for matching measure from cqf-ruler datastore by resource id
        # TODO: actually pull measure from user input drop down (populated from embedded client)
        measure_to_test = MEASURES[0]
        measure_identifier, measure_version = measure_to_test.split('|')

        # @client.additional_headers = { 'x-api-key': @instance.api_key, 'Authorization': @instance.auth_header } if @instance.api_key && @instance.auth_header

        # Search system for measure by identifier and version
        fhir_search(:measure, params: { name: measure_identifier, version: measure_version }, name: :measure_search)
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
        measure_bundle = JSON.parse(response[:body])
        assert measure_bundle["total"].positive?, "Expected to find measure with identifier #{measure_identifier} and version #{measure_version}"
      end
    end
  end
end