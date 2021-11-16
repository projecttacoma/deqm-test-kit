# frozen_string_literal: true

RSpec.describe DEQMTestKit::PatientEverything do
    let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
    let(:group) { suite.groups[4] }
    let(:session_data_repo) { Inferno::Repositories::SessionData.new }
    let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
    let(:url) { 'http://example.com/fhir' }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

    def run(runnable, inputs = {})
        test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
        test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
        inputs.each do |name, value|
            session_data_repo.save(test_session_id: test_session.id, name: name, value: value)
        end
        Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
    end

    # describe 'Patient/$everything successful test' do
    #     let(:test) { group.tests.first }

    #     it 'passes for valid request to Patient/<id>/$everything' do



    #     end


    #     it 'passes for valid request to Patient/$everything' do


    #     end
    # end

    describe 'Patient/<id>/$everything fails for invalid id' do
        let (:test) { group.tests.first }

        it 'passes with correct Operation-Outcome returned' do
            stub_request(:post, "#{url}/Patient/INVALID/$everything")
              .to_return(status: 404, body: error_outcome.to_json)
            result = run(test, url: url)
            expect(result.result).to eq('pass')
        end

        it 'fails when server does not return 404' do
            stub_request(
                :post,
                "#{url}/Patient/INVALID/$everything"
            )
                .to_return(status: 200, body: error_outcome.to_json)
            result = run(test, url: url)
            expect(result.result).to eq('fail')
        end
    end
end


