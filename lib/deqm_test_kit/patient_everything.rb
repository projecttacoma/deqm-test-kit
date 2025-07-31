# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # Perform Patient/$everything operation on test client
  class PatientEverything < Inferno::TestGroup
    # module for shared code for Patient/$everything assertions and requests
    module PatientEverythingHelpers
      def patient_everything_assert_success(endpoint, body)
        fhir_operation('/', body:)
        fhir_operation(endpoint)
        assert_success(:bundle, 200)
      end
    end
    id 'patient_everything'
    title 'Patient/$everything'
    description 'Ensure FHIR server can respond to the Patient/$everything request'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    TEST_PATIENT_ID = 'test-patient'

    test do
      include PatientEverythingHelpers
      title 'Patient/<id>/$everything valid submission'
      id 'patient-everything-single-patient'
      description 'Patient data is received for single patient on the server'

      run do
        single_patient_file = File.open('./lib/fixtures/singlePatientBundle.json')
        single_patient_bundle = JSON.parse(single_patient_file.read)
        # Upload single patient bundle to server
        patient_everything_assert_success("Patient/#{TEST_PATIENT_ID}/$everything", single_patient_bundle)
        # Run Patient/<id>/$everything operation on the test client server

        # Check all necessary resources are included in the response
        # Note Condition resource does not include patient ref, so subtract 1
        assert(single_patient_bundle['entry'].length - 1 == resource.total,
               "Expected #{single_patient_bundle['entry'].length - 1} in response but received #{resource.total}")
        # Check that all necessary resources are included in response
        assert(resource.entry.count { |x| x.resource.resourceType == 'Encounter' } == 1)
        assert(resource.entry.count { |x| x.resource.resourceType == 'Procedure' } == 1)
        assert(resource.entry.count { |x| x.resource.resourceType == 'Patient' } == 1)
      end
    end

    test do
      include PatientEverythingHelpers
      title 'Patient/$everything valid submission'
      id 'patient-everything-all-patients'
      description 'Patient data is received for all patients on the server'

      run do
        multiple_patient_file = File.open('./lib/fixtures/multiplePatientBundle.json')
        multiple_patient_bundle = JSON.parse(multiple_patient_file.read)
        # Upload multiple patient bundle to server
        patient_everything_assert_success('Patient/$everything', multiple_patient_bundle)
        # Check all necessary resources are included in the response
        # Note all resources should be included because they all reference a patient
        # Use >=, as other data may be retrieved from server in addition to what we expect
        assert(resource.total >= multiple_patient_bundle['entry'].length)
        # Check that all necessary resources are included in response
        assert(resource.entry.count { |x| x.resource.resourceType == 'Patient' } >= 2)
        assert(resource.entry.count { |x| x.resource.resourceType == 'Encounter' } >= 1)
        assert(resource.entry.count { |x| x.resource.resourceType == 'Procedure' } >= 1)
        assert(resource.entry.count { |x| x.resource.resourceType == 'Condition' } >= 1)
      end
    end

    test do
      title 'Patient/<id>/$everything patient ID not found'
      id 'patient-everything-invalid-patient-id'
      description 'Request returns a 404 error if requested patient ID is not found'

      run do
        # Run Patient/$everything operation on the test client server with invalid id
        fhir_operation('Patient/INVALID/$everything')
        assert_valid_json(response[:body])
        assert_response_status(404)
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
  end
end
