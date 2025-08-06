# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # MeasureAvailability test group ensures selected measures are available on the fhir server
  class MeasureAvailability < Inferno::TestGroup
    # module for shared code for measure availability assertions and requests
    module MeasureAvailabilityHelpers
      def measure_availability_assert_success(measure_identifier, measure_version = nil)
        if measure_version.nil?
          fhir_search(:measure, params: { name: measure_identifier })
        else
          fhir_search(:measure, params: { name: measure_identifier, version: measure_version })
        end
        assert_success(:bundle, 200)
      end
    end
    id 'measure_availability'
    title 'Measure Availability'
    description 'Ensure selected measures are available on the fhir server'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'ColorectalCancerScreeningsFHIR',
                        options: measure_options, title: 'Measure Title' }

    test do
      include MeasureAvailabilityHelpers
      title 'Measure can be found'
      id 'measure-availability-found'
      description 'Selected measure with matching id is available on the server and a valid json object'
      makes_request :measure_search
      input :selected_measure_id, **measure_id_args
      output :measure_id
      run do
        if selected_measure_id.include?('|')
          measure_to_test, measure_version = selected_measure_id.split('|')
          measure_availability_assert_success(measure_to_test, measure_version)
        else
          measure_availability_assert_success(selected_measure_id)
        end
        assert resource.total.positive?,
               "Expected to find measure with identifier #{measure_to_test}"
        output measure_id: resource.entry[0].resource.id
      end
    end
    test do
      include MeasureAvailabilityHelpers
      title 'Measure cannot be found returns empty bundle'
      id 'measure-availability-not-found'
      description 'Selected measure is know not to exist on the server and returns an empty bundle'
      makes_request :measure_search_failure
      output :null

      run do
        measure_identifier = 'NON-EXISTENT_MEASURE_ID'
        measure_availability_assert_success(measure_identifier)
        assert resource.total.zero?,
               "Expected to return empty bundle when passed\"
               identifier #{measure_identifier}"
      end
    end
  end
end
