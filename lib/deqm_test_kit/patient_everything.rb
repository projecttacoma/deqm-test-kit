# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # Perform Patient/$everything operation on test client
  class PatientEverything < Inferno::TestGroup
    id 'patient_everything'
    title 'Patient/$everything'
    description 'Ensure FHIR server can respond to the Patient/$everything request'

    fhir_client do
      url :url
    end

    TEST_PATIENT_ID = 'test-patient'

    test do
      title 'Patient/<id>/$everything valid submission'
      id 'patient-everything-01'
      description 'Patient data is received for single patient on the server'

      run do
        single_patient_file = File.open('./lib/fixtures/singlePatientBundle.json')
        single_patient_bundle = JSON.parse(single_patient_file.read)
        # Upload single patient bundle to server
        fhir_operation('/', body: single_patient_bundle)
        # Run Patient/<id>/$everything operation on the test client server
        fhir_operation("Patient/#{TEST_PATIENT_ID}/$everything")
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
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
      title 'Patient/$everything valid submission'
      id 'patient-everything-02'
      description 'Patient data is received for all patients on the server'

      run do
        multiple_patient_file = File.open('./lib/fixtures/multiplePatientBundle.json')
        multiple_patient_bundle = JSON.parse(multiple_patient_file.read)
        # Upload multiple patient bundle to server
        fhir_operation('/', body: multiple_patient_bundle)
        # Run Patient/$everything operation on the test client server
        fhir_operation('Patient/$everything')
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
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
      id 'patient-everything-03'
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
