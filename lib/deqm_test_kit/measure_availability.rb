# frozen_string_literal: true

module DEQMTestKit
  # MeasureAvailability test group ensures selected measures are available on the fhir server
  class MeasureAvailability < Inferno::TestGroup
    id 'measure_availability'
    title 'Measure Availability'
    description 'Ensure selected measures are available on the fhir server'

    fhir_client do
      url :url
    end
    # rubocop:disable Metrics/BlockLength
    test do
      title 'Measure can be found'
      id 'measure-availability-01'
      description 'Selected measure with matching id is available on the server and a valid json object'
      makes_request :measure_search
      input :selected_measure_id, type: 'radio', optional: false,
                                  default: 'EXM130|7.3.000', options: {
                                    list_options: [
                                      {
                                        label: 'EXM104',
                                        value: 'EXM104|8.2.000'
                                      },
                                      {
                                        label: 'EXM105',
                                        value: 'EXM105|8.2.000'
                                      },
                                      {
                                        label: 'EXM124',
                                        value: 'EXM124|9.0.000'
                                      },
                                      {
                                        label: 'EXM125',
                                        value: 'EXM125|7.3.000'
                                      },
                                      {
                                        label: 'EXM130',
                                        value: 'EXM130|7.3.000'
                                      }
                                    ]
                                  }
      output :measure_id
      run do
        # Look for matching measure from cqf-ruler datastore by resource id
        # TODO: actually pull measure from user input drop down (populated from embedded client)
        measure_to_test = selected_measure_id
        measure_identifier, measure_version = measure_to_test.split('|')

        # Search system for measure by identifier and version
        fhir_search(:measure, params: { name: measure_identifier, version: measure_version }, name: :measure_search)
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
        assert resource.total.positive?,
               "Expected to find measure with identifier #{measure_identifier} and version #{measure_version}"
        output measure_id: resource.entry[0].resource.id
      end
    end
    # rubocop:enable Metrics/BlockLength

    test do
      title 'Measure cannot be found returns empty bundle'
      id 'measure-availability-02'
      description 'Selected measure is know not to exist on the server and returns an empty bundle'
      makes_request :measure_search_failure
      output :null

      run do
        measure_identifier = 'NON-EXISTENT_MEASURE_ID'
        measure_version = '0'

        # Search system for measure by identifier and version
        fhir_search(:measure, params: { name: measure_identifier, version: measure_version })
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
        assert resource.total.zero?,
               "Expected to return empty bundle when passed\"
               identifier #{measure_identifier} and version #{measure_version}"
      end
    end
  end
end
