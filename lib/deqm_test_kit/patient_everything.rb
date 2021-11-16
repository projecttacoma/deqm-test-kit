# frozen_string_literal: true
require "json"




module DEQMTestKit
  # Perform Patient/$everything operation on test client
  class PatientEverything < Inferno::TestGroup
    id 'patient_everything'
    title 'Patient/$everything'
    description 'Ensure fhir server can respond to the Patient/$everything request'

    fhir_client do
      url :url
    end

    TEST_PATIENT_ID = 'test-patient'

    # rubocop:disable Metrics/BlockLength
    test do
      title 'Patient/<id>/$everything valid submission'
      id 'patient-everything-01'
      description 'Patient data is received for patient on the server'
      makes_request :patient_everything
      output :queries_json

      run do
        singlePatientBundle = File.open('./lib/fixtures/singlePatientBundle.json')
        singlePatientData = JSON.parse(singlePatientBundle.read)
        # Upload single patient bundle to server
        fhir_operation("/", body: singlePatientData)
        # Run our Patient/<id>/$everything operation on the test client server
        fhir_operation("Patient/#{TEST_PATIENT_ID}/$everything", name: :patient_everything)
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
        # Check all necessary resources are included in the response
        # Note Condition resource does not include patient ref
        assert(singlePatientData["entry"].length() - 1 == resource.total, "Expected #{singlePatientData["entry"].length() - 1} in response but received #{resource.total}")
        # Check that all necessary resources are included in response
        assert(resource.entry.count { |x| x.resource.resourceType == "Encounter"} == 1)
        assert(resource.entry.count { |x| x.resource.resourceType == "Procedure"} == 1)
        assert(resource.entry.count { |x| x.resource.resourceType == "Patient"} == 1)
      end
    end

    test do
      title 'Patient/$everything valid submission'
      id 'patient-everything-02'
      description 'Patient data is received for all patients on the server'
      makes_request :patient_everything
      output :queries_json

      run do
        multiplePatientBundle = File.open('./lib/fixtures/multiplePatientBundle.json')
        multiplePatientData = JSON.parse(multiplePatientBundle.read)
        # Upload multiple patient bundle to server
        fhir_operation("/", body: multiplePatientData)
        # Run our Patient/$everything operation on the test client server
        fhir_operation("Patient/$everything", name: :patient_everything)
        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
        # Check all necessary resources are included in the response
        # Note all resources should be included because they all reference a patient
        assert(resource.total >= multiplePatientData["entry"].length())
        # Check that all necessary resources are included in response
        assert(resource.entry.count { |x| x.resource.resourceType == "Patient"} >= 2)
        assert(resource.entry.count { |x| x.resource.resourceType == "Encounter"} >= 1)
        assert(resource.entry.count { |x| x.resource.resourceType == "Procedure"} >= 1)
        assert(resource.entry.count { |x| x.resource.resourceType == "Condition"} >= 1)

      end
    end

    test do
      title 'Patient/<id>/$everything patient ID not found'
      id 'patient-everything-03'
      description 'Request returns a 404 error if requested patient ID is not found'
      makes_request :patient_everything

      run do
        # Run our Patient/$everything operation on the test client server with invalid id
        fhir_operation("Patient/INVALID/$everything", name: :patient_everything)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end


    # rubocop:enable Metrics/BlockLength
  end
end
