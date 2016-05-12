require 'helper'

RSpec.describe Flipper::UI::Actions::Feature do
  describe "DELETE /features/:feature" do
    before do
      flipper.enable :search
      delete "/features/search",
        {"authenticity_token" => "a"},
        "rack.session" => {"_csrf_token" => "a"}
    end

    it "removes feature" do
      expect(flipper.features.map(&:key)).not_to include("search")
    end

    it "redirects to features" do
      expect(last_response.status).to be(302)
      expect(last_response.headers["Location"]).to eq("/features")
    end
  end

  describe "POST /features/:feature with _method=DELETE" do
    before do
      flipper.enable :search
      post "/features/search",
        {"_method" => "DELETE", "authenticity_token" => "a"},
        "rack.session" => {"_csrf_token" => "a"}
    end

    it "removes feature" do
      expect(flipper.features.map(&:key)).not_to include("search")
    end

    it "redirects to features" do
      expect(last_response.status).to be(302)
      expect(last_response.headers["Location"]).to eq("/features")
    end
  end

  describe "GET /features/:feature" do
    before do
      get "/features/search"
    end

    it "responds with success" do
      expect(last_response.status).to be(200)
    end

    it "renders template" do
      expect(last_response.body).to include("search")
      expect(last_response.body).to include("Enable")
      expect(last_response.body).to include("Disable")
      expect(last_response.body).to include("Actors")
      expect(last_response.body).to include("Groups")
      expect(last_response.body).to include("Percentage of Time")
      expect(last_response.body).to include("Percentage of Actors")
    end
  end

  describe "GET /features/:feature with boolean gate deactivated" do
    before do
      flipper[:search].deactivate :boolean
      get "/features/search"
    end

    it "responds with success" do
      expect(last_response.status).to be(200)
    end

    it "renders template" do
      expect(last_response.body).to include("The boolean gate is disabled for this feature.")
    end
  end

  describe "GET /features/:feature with percentage_of_actors gate deactivated" do
    before do
      flipper[:search].deactivate :percentage_of_actors
      get "/features/search"
    end

    it "responds with success" do
      expect(last_response.status).to be(200)
    end

    it "renders template" do
      expect(last_response.body).to include("The percentage of actors gate is disabled for this feature.")
    end
  end

  describe "GET /features/:feature with percentage_of_time gate deactivated" do
    before do
      flipper[:search].deactivate :percentage_of_time
      get "/features/search"
    end

    it "responds with success" do
      expect(last_response.status).to be(200)
    end

    it "renders template" do
      expect(last_response.body).to include("The percentage of time gate is disabled for this feature.")
    end
  end

  describe "GET /features/:feature with group gate deactivated" do
    before do
      flipper[:search].deactivate :group
      get "/features/search"
    end

    it "responds with success" do
      expect(last_response.status).to be(200)
    end

    it "renders template" do
      expect(last_response.body).to include("The groups gate is disabled for this feature.")
    end
  end

  describe "GET /features/:feature with actor gate deactivated" do
    before do
      flipper[:search].deactivate :actor
      get "/features/search"
    end

    it "responds with success" do
      expect(last_response.status).to be(200)
    end

    it "renders template" do
      expect(last_response.body).to include("The individual actors gate is disabled for this feature.")
    end
  end
end
