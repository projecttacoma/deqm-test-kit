# frozen_string_literal: true

RSpec.describe DEQMTestKit::SubmitDataV5 do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v500') }
  let(:group) { suite.groups[6] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  submit_data_response = File.read('./spec/fixtures/submitDataResponse.json')

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'Submit Data valid submission (one subject, multiple measures)' do
    let(:test) { test_by_id(group, 'submit-data-valid-one-subject-multi-measures') }

    it 'passes with comma-separated measures format' do
      stub_request(:post, "#{url}/Measure/$submit-data")
        .to_return(status: 200, body: submit_data_response)

      result = run(test, {
                     url:,
                     measure_url_list: 'http://example.org/Measure/B|1.2.3,http://example.org/Measure/C|2.0.0',
                     period_start: '2026-01-01',
                     period_end: '2026-12-31'
                   })
      expect(result.result).to eq('pass')
    end

    it 'fails if $submit-data does not return 200' do
      stub_request(:post, "#{url}/Measure/$submit-data")
        .to_return(status: 400, body: submit_data_response)

      result = run(test, {
                     url:,
                     measure_url_list: 'http://example.org/Measure/B|1.2.3,http://example.org/Measure/C|2.0.0',
                     period_start: '2026-01-01',
                     period_end: '2026-12-31'
                   })
      expect(result.result).to eq('fail')
    end
  end

  describe 'Submit Data valid submission (two subjects, multiple measures each)' do
    let(:test) { test_by_id(group, 'submit-data-valid-two-subjects-multi-measures') }

    it 'passes with comma-separated measures format' do
      stub_request(:post, "#{url}/Measure/$submit-data")
        .to_return(status: 200, body: submit_data_response)

      result = run(test, {
                     url:,
                     measure_url_list: 'http://example.org/Measure/A|1.0.0,http://example.org/Measure/B|1.2.3',
                     period_start: '2026-01-01',
                     period_end: '2026-12-31'
                   })
      expect(result.result).to eq('pass')
    end

    it 'fails if $submit-data does not return 200' do
      stub_request(:post, "#{url}/Measure/$submit-data")
        .to_return(status: 400, body: submit_data_response)

      result = run(test, {
                     url:,
                     measure_url_list: 'http://example.org/Measure/A|1.0.0,http://example.org/Measure/B|1.2.3',
                     period_start: '2026-01-01',
                     period_end: '2026-12-31'
                   })
      expect(result.result).to eq('fail')
    end
  end
end
