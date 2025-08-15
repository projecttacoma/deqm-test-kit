# frozen_string_literal: true

RSpec.describe DEQMTestKit::SubmitDataV5 do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v500') }
  let(:group) { suite.groups[6] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:data_requirements_reference_server) { 'http://example.com/reference/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'STU5 $submit-data successful upload test' do
    let(:test) { test_by_id(group, 'stu5-submit-data-valid-submission') }

    it 'passes if the submitted resources can be retrieved' do
      test_bundle = FHIR::Bundle.new(total: 1)
      test_measure = FHIR::Measure.new(id: 'test-measure-id', url: 'http://example.com/Measure/test')
      identifier = SecureRandom.uuid
      id_resource = FHIR::Identifier.new({ value: identifier })
      test_patient = FHIR::Bundle.new(total: 1,
                                      entry: [resource: FHIR::Patient.new({
                                                                            id: 'PatientID', identifier: [id_resource]
                                                                          })])
      test_measures_bundle = FHIR::Bundle.new(total: 1,
                                              entry: [resource: test_measure])
      queries_json = [{ endpoint: 'Patient', params: {} }].to_json

      stub_request(:get, "#{url}/Measure")
        .to_return(status: 200, body: test_measures_bundle.to_json)

      stub_request(:get, "#{data_requirements_reference_server}/Patient")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 200, body: {}.to_json)

      stub_request(:get, "#{url}/Patient?identifier=#{identifier}")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:get, %r{#{url}/MeasureReport\?identifier=.*})
        .to_return(status: 200, body: test_bundle.to_json)

      result = run(test, url:, queries_json:,
                         data_requirements_reference_server:)
      expect(result.result).to eq('pass')
    end

    it 'fails if $submit-data does not return 200' do
      test_measure = FHIR::Measure.new(id: 'test-measure-id', url: 'http://example.com/Measure/test')
      identifier = SecureRandom.uuid
      id_resource = FHIR::Identifier.new({ value: identifier })
      test_patient = FHIR::Bundle.new(total: 1,
                                      entry: [resource: FHIR::Patient.new({
                                                                            id: 'PatientID', identifier: [id_resource]
                                                                          })])
      test_measures_bundle = FHIR::Bundle.new(total: 1,
                                              entry: [resource: test_measure])
      queries_json = [{ endpoint: 'Patient', params: {} }].to_json

      stub_request(:get, "#{url}/Measure")
        .to_return(status: 200, body: test_measures_bundle.to_json)

      stub_request(:get, "#{data_requirements_reference_server}/Patient")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: {}.to_json)

      result = run(test, url:, queries_json:,
                         data_requirements_reference_server:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'STU5 $submit-data failed on Parameters object with no bundles' do
    let(:test) { test_by_id(group, 'stu5-submit-data-fails-no-bundles') }

    it 'passes when server returns 400 with correct operation outcome' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:)
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 400' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:)
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns 400 with incorrect body' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: '')

      result = run(test, url:)
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns correct status code with incorrect severity' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: FHIR::OperationOutcome.new(issue: [{ severity: 'warning' }]).to_json)
      result = run(test, url:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'STU5 $submit-data failed on bundle with no MeasureReport' do
    let(:test) { test_by_id(group, 'stu5-submit-data-fails-no-measurereport') }

    it 'passes when server returns 400 with correct operation outcome' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:)
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 400' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:)
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns 400 with incorrect body' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: '')

      result = run(test, url:)
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns correct status code with incorrect severity' do
      stub_request(:post, "#{url}/$submit-data")
        .to_return(status: 400, body: FHIR::OperationOutcome.new(issue: [{ severity: 'warning' }]).to_json)
      result = run(test, url:)
      expect(result.result).to eq('fail')
    end
  end
end
