# frozen_string_literal: true

require_relative "../lib/requests"

# Unit coverage for Requests' URL and request-shaping logic, isolated from
# the live network call: upstream's src/requests.py builds this same URL and
# header set deterministically, and this is the part of lib/requests.rb that
# does not need an actual HTTP round trip to assert on.
RSpec.describe Requests::ECB do
  subject(:provider) { described_class.new("USD", "EUR", "12.5") }

  describe "#mount_url" do
    it "builds the frankfurter.app URL from the amount and currency pair" do
      expect(provider.mount_url).to eq(
        "https://api.frankfurter.app/latest?amount=12.5&from=USD&to=EUR",
      )
    end
  end

  describe "#default_response" do
    it "shapes the provider's JSON body into the response Hash the window reads" do
      data = {
        "date" => "2024-01-01",
        "rates" => { "EUR" => 0.91 },
      }

      serialized = provider.default_response(data)

      expect(serialized).to include(
        "base" => 0.91,
        "from" => "USD",
        "to" => "EUR",
        "amount" => 0,
        "provider" => Requests::ECB::INDEX,
        "disclaimer" => provider.mount_url,
      )
      expect(serialized["info"]).to eq("January  1, 2024")
    end
  end
end

RSpec.describe Requests::SoupSession do
  describe "#create_request" do
    it "sets the default User-Agent header on the built Soup::Message" do
      message = described_class.new.create_request("GET", "https://example.test")

      expect(message.request_headers.get_one("User-Agent")).to eq(Requests::HEADERS["User-Agent"])
    end

    it "merges extra headers on top of the defaults without dropping them" do
      message = described_class.new.create_request("GET", "https://example.test", "Accept" => "application/json")

      expect(message.request_headers.get_one("Accept")).to eq("application/json")
      expect(message.request_headers.get_one("User-Agent")).to eq(Requests::HEADERS["User-Agent"])
    end
  end
end

RSpec.describe Requests do
  describe "#get" do
    it "returns the error message instead of raising when the provider lookup fails" do
      requests = described_class.new(0, "USD", "EUR", "10")
      broken_session = instance_double(Requests::SoupSession)
      allow(Requests::SoupSession).to receive(:new).and_return(broken_session)
      allow(broken_session).to receive(:create_request).and_return(:message)
      allow(broken_session).to receive(:get_response).with(:message).and_raise(IOError, "500 Internal Server Error")

      expect(requests.get).to eq("500 Internal Server Error")
    end
  end
end
