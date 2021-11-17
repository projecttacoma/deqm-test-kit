# frozen_string_literal: true

# Utility functions in support of the bulk import test group
module DEQMTestKit
  # Utility functions in support of the bulk import test group
  module BulkImportUtils
    def get_retry_or_backoff_time(wait_time, reply)
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
    def loop_on_polling(polling_url)
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
  end
end
