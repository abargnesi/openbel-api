require 'bel'
require 'cgi'
require 'evidence/facet_filter'
require 'base_libs/resources/evidence_transform'
require 'mongo'

# emitting evidence events
require 'hermann'
require 'hermann/producer'

module OpenBEL
  module Routes

    class Evidence < Base
      include OpenBEL::Evidence::FacetFilter
      include OpenBEL::Resource::Evidence

      def initialize(app)
        super
        @api = OpenBEL::Settings["evidence-api"].create_instance
        annotation_api = OpenBEL::Settings["annotation-api"].create_instance
        @annotation_transform = AnnotationTransform.new(annotation_api)
        @annotation_grouping_transform = AnnotationGroupingTransform.new
      end

      options '/api/evidence' do
        response.headers['Allow'] = 'OPTIONS,POST,GET'
        status 200
      end

      options '/api/evidence/:id' do
        response.headers['Allow'] = 'OPTIONS,GET,PUT,DELETE'
        status 200
      end

      post '/api/evidence' do
        _id = nil
        read_evidence.each do |evidence|
          @annotation_transform.transform_evidence!(evidence, base_url)

          # XXX Not sure we need to group values together. Instead we split
          # multi-valued items into individual objects.
          # Wait and see what breaks.
          @annotation_grouping_transform.transform_evidence!(evidence)

          facets = map_evidence_facets(evidence)
          hash = evidence.to_h
          hash[:bel_statement] = hash.fetch(:bel_statement, nil).to_s
          hash[:facets]        = facets
          _id = @api.create_evidence(hash)
        end

        status 201
        headers "Location" => "#{base_url}/api/evidence/#{_id}"
      end

      get '/api/evidence' do
        start    = (params[:start]  || 0).to_i
        size     = (params[:size]   || 0).to_i
        faceted  = as_bool(params[:faceted])

        # check filters
        filters = []
        filter_params = CGI::parse(env["QUERY_STRING"])['filter']
        filter_params.each do |filter|
          filter = read_filter(filter)
          halt 400 unless ['category', 'name', 'value'].all? { |f| filter.include? f}

          if filter['category'] == 'fts' && filter['name'] == 'search'
            halt 400 unless filter['value'].to_s.length > 1
          end

          filters << filter
        end

        results  = @api.find_evidence(filters, start, size, faceted)
        evidence = results[:cursor].to_a
        facets   = results[:facets]

        halt 404 if evidence.empty?

        options = {
          :start   => start,
          :size    => size,
          :filters => filter_params
        }
        if facets
          facet_hashes = facets.map { |facet|
            filter = read_filter(facet['_id'])
            {
              :category => filter['category'].to_sym,
              :name     => filter['name'].to_sym,
              :value    => filter['value'],
              :filter   => facet['_id'],
              :count    => facet['count']
            }
          }
          options[:facets] = facet_hashes
        end

        render_collection(evidence, :evidence, options)
      end

      get '/api/evidence/:id' do
        object_id = params[:id]
        halt 404 unless BSON::ObjectId.legal?(object_id)

        evidence = @api.find_evidence_by_id(object_id)
        halt 404 unless evidence

        # XXX Hack to return single resource wrapped as json array
        # XXX Need to better support evidence resource arrays in base.rb
        render(
          evidence,
          :evidence,
          :as_array => true
        )
      end

      put '/api/evidence/:id' do
        object_id = params[:id]
        halt 404 unless BSON::ObjectId.legal?(object_id)

        validate_media_type! "application/json", :profile => schema_url('evidence')

        ev = @api.find_evidence_by_id(object_id)
        halt 404 unless ev

        evidence_obj = read_json
        schema_validation = validate_schema(evidence_obj, :evidence)
        unless schema_validation[0]
          halt(
            400,
            { 'Content-Type' => 'application/json' },
            render_json({ :status => 400, :msg => schema_validation[1].join("\n") })
          )
        end

        # transformation
        evidence = evidence_obj['evidence']
        evidence = @annotation_transform.transform_evidence(evidence)
        evidence[:facets] = map_evidence_facets(evidence)

        @api.update_evidence_by_id(object_id, evidence)

        status 202
      end

      delete '/api/evidence/:id' do
        object_id = params[:id]
        halt 404 unless BSON::ObjectId.legal?(object_id)

        ev = @api.find_evidence_by_id(object_id)
        halt 404 unless ev

        @api.delete_evidence_by_id(object_id)
        status 202
      end
    end
  end
end
# vim: ts=2 sw=2:
# encoding: utf-8