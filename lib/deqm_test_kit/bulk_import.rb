# frozen_string_literal: true

module DEQMTestKit
    # BulkImport test group ensure the fhir server can accept bulk data import requests
    class BulkImport < Inferno::TestGroup
      id 'bulk_import'
      title 'Bulk Import'
      description 'Ensure the fhir server can accept bulk data import requests'
      input :measure_id
      fhir_client do
        url :url
      end  
      test do
        title 'Ensure data can be accepted'
        id 'bulk-import-01'
        description 'Send the data to the server and the response is a 202 (or is it?)'
       #need to modify docker compose to start bulk reference server
  
       run do

        # get measure from client
        assert(measure_id,
        'No measure selected. Run Measure Availability prior to running the bulk import test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        measure = resource
        measure_report = create_measure_report(measure.url, '2019-01-01', '2019-12-31')
        params = {
          {
            "resourceType": "Parameters",
            "parameter": [
              {
                "name": "measureReport",
                "resource": {
                  "resourceType": "MeasureReport",
                  "measure": "http://hl7.org/fhir/us/cqfmeasures/Measure/EXM130"
                }
              },
              {
                "name": "exportURL",
                "valueString": "https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibSI6MSwic3R1IjozLCJkZWwiOjB9/fhir"
              }
            ]
          }
          }
       fhir_operation("Measure/#{measure_id}/$submit-data", headers:"prefer": "respond-async" ,body: params, name: :submit_data)
       reply = fhir_client(:url).send(:get, '$bulkstatus')
       content_location = reply.headers('Content-Location')
       polling_url = url + reply.headers('Content-Location') #base url plus content location header value

       fhir_operation('$bulkstatus',polling_url)
       wait_time = 1
       reply = nil
       start = Time.now
      seconds_used = 0
           
         loop do
              reply = nil
              begin
                reply = fhir_client.client.get(polling_url)
              rescue RestClient::TooManyRequests => e
                reply = e.response
              end
              wait_time = get_retry_or_backoff_time(wait_time, reply)
              seconds_used = Time.now - start
              # exit loop if we get a successful response or timeout reached
              break if (reply.code != 202 && reply.code != 429) || (seconds_used > timeout)
      
              sleep wait_time
        end
      end
      def self.get_retry_or_backoff_time(wait_time, reply)
        retry_after = -1
        unless reply.headers.nil?
          reply.headers.symbolize_keys
          retry_after = reply.headers[:retry_after].to_i || -1
        end
  
        if retry_after.positive?
          retry_after
        else
          wait_time * 2
        end
      end
    end
  end
  

  #remember that the bulk import request is a measure report and the link to the bulk export server 
  #(the test server can handle all the other logic)
  # the export server can be the link to the smart on fhir  
  #don't need to loop or create every resource can just hardcode link to bulk export server