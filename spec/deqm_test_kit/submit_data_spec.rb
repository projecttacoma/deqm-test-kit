# frozen_string_literal: true

RSpec.describe DEQMTestKit::SubmitData do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[4] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  # ensure this url matches url in embedded_client in data_requirements.rb
  let(:embedded_client) do
    'http://cqf_ruler:8080/cqf-ruler-r4/fhir'
  end
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value, type: 'text')
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe '$submit-data successful upload test' do
    let(:test) { group.tests.first }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes if the submitted resources can be retrieved' do
      test_bundle = FHIR::Bundle.new(total: 1)
      test_measure = FHIR::Measure.new(id: measure_id)
      identifier = SecureRandom.uuid
      id_resource = FHIR::Identifier.new({ value: identifier })
      test_patient = FHIR::Bundle.new(total: 1,
                                      entry: [resource: FHIR::Patient.new({
                                                                            id: 'PatientID', identifier: [id_resource]
                                                                          })])
      queries_json = [{ endpoint: 'Patient', params: {} }].to_json

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      # TODO: update, needs both get and post
      stub_request(:get, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)
      stub_request(:post, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)

      stub_request(:get, "#{embedded_client}/Patient")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 200, body: {}.to_json)

      stub_request(:get, "#{url}/Patient?identifier=#{identifier}")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:get, %r{#{url}/MeasureReport\?identifier=.*})
        .to_return(status: 200, body: test_bundle.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: queries_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if $submit-data does not return 200' do
      test_bundle = FHIR::Bundle.new(total: 1)
      test_measure = FHIR::Measure.new(id: measure_id)
      identifier = SecureRandom.uuid
      id_resource = FHIR::Identifier.new({ value: identifier })
      test_patient = FHIR::Bundle.new(total: 1,
                                      entry: [resource: FHIR::Patient.new({
                                                                            id: 'PatientID', identifier: [id_resource]
                                                                          })])
      queries_json = [{ endpoint: 'Patient', params: {} }].to_json

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      # TODO: update, needs both get and post
      stub_request(:get, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)
      stub_request(:post, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)

      stub_request(:get, "#{embedded_client}/Patient")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: {}.to_json)

      stub_request(:get, "#{url}/Patient?identifier=#{identifier}")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:get, %r{#{url}/MeasureReport\?identifier=.*})
        .to_return(status: 200, body: test_bundle.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: queries_json)
      expect(result.result).to eq('fail')
    end

    it 'fails if the submitted retrieval does not return 200' do
      test_bundle = FHIR::Bundle.new(total: 1)
      test_measure = FHIR::Measure.new(id: measure_id)
      identifier = SecureRandom.uuid
      id_resource = FHIR::Identifier.new({ value: identifier })
      test_patient = FHIR::Bundle.new(total: 1,
                                      entry: [resource: FHIR::Patient.new({
                                                                            id: 'PatientID', identifier: [id_resource]
                                                                          })])
      queries_json = [{ endpoint: 'Patient', params: {} }].to_json

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      # TODO: update, needs both get and post
      stub_request(:get, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)
      stub_request(:post, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)

      stub_request(:get, "#{embedded_client}/Patient")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 200, body: {}.to_json)

      stub_request(:get, "#{url}/Patient?identifier=#{identifier}")
        .to_return(status: 400)

      stub_request(:get, %r{#{url}/MeasureReport\?identifier=.*})
        .to_return(status: 200, body: test_bundle.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: queries_json)
      expect(result.result).to eq('fail')
    end

    it 'fails if the submitted resource cannot be found' do
      test_bundle = FHIR::Bundle.new(total: 1)
      test_measure = FHIR::Measure.new(id: measure_id)
      identifier = SecureRandom.uuid
      id_arr = [FHIR::Identifier.new({ value: identifier })]
      test_patient = FHIR::Bundle.new(total: 1,
                                      entry: [resource: FHIR::Patient.new({
                                                                            id: 'PatientID', identifier: id_arr
                                                                          })])
      wrong_patient = FHIR::Bundle.new(total: 0)
      queries_json = [{ endpoint: 'Patient', params: {} }].to_json

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      # TODO: update, needs both get and post
      stub_request(:get, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)
      stub_request(:post, "#{embedded_client}/$updateCodeSystems")
        .to_return(status: 200)

      stub_request(:get, "#{embedded_client}/Patient")
        .to_return(status: 200, body: test_patient.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 200, body: {}.to_json)

      stub_request(:get, "#{url}/Patient?identifier=#{identifier}")
        .to_return(status: 200, body: wrong_patient.to_json)

      stub_request(:get, %r{#{url}/MeasureReport\?identifier=.*})
        .to_return(status: 200, body: test_bundle.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: queries_json)
      expect(result.result).to eq('fail')
    end
  end
  describe '$submit-data failed on Parameters object with no MeasureReport' do
    let(:test) { group.tests[1] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes when server returns 400 with correct operation outcome' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 400' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns 400 with incorrect body' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: '')

      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns correct status code with incorrect severity' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: FHIR::OperationOutcome.new(issue: [{ severity: 'warning' }]).to_json)
      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('fail')
    end
  end

  describe '$submit-data failed on Parameters object with multiple MeasureReports' do
    let(:test) { group.tests[2] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes when server returns 400 with correct operation outcome' do
      test_measure = FHIR::Measure.new(id: measure_id)
      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 400' do
      test_measure = FHIR::Measure.new(id: measure_id)
      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns 400 with incorrect body' do
      test_measure = FHIR::Measure.new(id: measure_id)
      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: '')

      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('fail')
    end

    it 'fails when server returns correct status code with incorrect severity' do
      test_measure = FHIR::Measure.new(id: measure_id)
      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$submit-data")
        .to_return(status: 400, body: FHIR::OperationOutcome.new(issue: [{ severity: 'warning' }]).to_json)
      result = run(test, url: url, measure_id: measure_id, queries_json: [])
      expect(result.result).to eq('fail')
    end
  end
end
