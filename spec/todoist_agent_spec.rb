require 'rails_helper'
require 'huginn_agent/spec_helper'
require 'uri'

describe Agents::TodoistAgent do
  before(:each) do
    @valid_options = {
      'token' => 'some_token_here',
      'content' => 'foobar',
    }
    @checker = Agents::TodoistAgent.new(:name => "TodoistAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = {
      'somekey' => 'somevalue',
    }

    @sent_requests = Array.new
    stub_request(:post, "https://todoist.com/API/v6/sync").
      to_return { |request|
	expect(request.headers["Content-Type"]).to eq("application/x-www-form-urlencoded")

	form_data = URI.decode_www_form(request.body)
	expect(form_data.assoc("token").last).to eq("some_token_here")

	json_data = ActiveSupport::JSON.decode(form_data.assoc("commands").last)
	expect(json_data.length).to eq(1)

	@sent_requests << req = json_data[0]

	case json_data[0]["type"]
	when "item_add"
	  json_response = {
	    "TempIdMapping" => {
	      json_data[0]["temp_id"] => 81662555
	    },
	    "seq_no_global" => 11248873939,
	    "seq_no" => 11248873939,
	    "UserId" => 9933517,
	    "SyncStatus" => {
	      json_data[0]["uuid"] => "oK"
	    },
	  }
	else
	  raise "Unexpected type: #{json_data[0]["type"]}"
	end

	{ status: 200, body: ActiveSupport::JSON.encode(json_response), headers: { "Content-type" => "application/json" } }
      }
  end

  describe "#receive" do
    it 'can create a new static item' do
      @checker.receive([@event])
      expect(@sent_requests.length).to eq(1)
      expect(@sent_requests[0]["type"]).to eq("item_add")
      expect(@sent_requests[0]["args"]["content"]).to eq("foobar")
    end

    it "passes date_string to the new item" do
      @checker.options["date_string"] = "today"
      expect(@checker).to be_valid

      @checker.receive([@event])
      expect(@sent_requests[0]["args"]["date_string"]).to eq("today")
    end

    it "passes project_id to the new item" do
      @checker.options["project_id"] = "23"
      expect(@checker).to be_valid

      @checker.receive([@event])
      expect(@sent_requests[0]["args"]["project_id"]).to eq(23)
    end

    it "passes priority to the new item" do
      @checker.options["priority"] = "3"
      expect(@checker).to be_valid

      @checker.receive([@event])
      expect(@sent_requests[0]["args"]["priority"]).to eq(3)
    end

    it "passes a single label to the new item" do
      @checker.options["labels"] = "23"
      expect(@checker).to be_valid

      @checker.receive([@event])
      expect(@sent_requests[0]["args"]["labels"]).to eq([23])
    end

    it "passes multiple labels to the new item" do
      @checker.options["labels"] = "23, 42"
      expect(@checker).to be_valid

      @checker.receive([@event])
      expect(@sent_requests[0]["args"]["labels"]).to eq([23, 42])
    end
  end
end
