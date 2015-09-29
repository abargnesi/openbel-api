require_relative 'base'

module OpenBEL
  module Resource
    module Annotations

      VOCABULARY_RDF = 'http://www.openbel.org/vocabulary/'

      class AnnotationSerializer < BaseSerializer
#        adapter Oat::Adapters::HAL
        schema do
          type     :annotation
          property :rdf_uri,    item.uri
          property :name,       item.prefLabel
          property :prefix,     item.prefix
          property :domain,     item.domain
        end
      end

      class AnnotationResourceSerializer < BaseSerializer
        adapter Oat::Adapters::HAL
        schema do
          type     :annotation
          property :annotation, item
          link     :self,       link_self(item[:prefix])
        end

        private

        def link_self(id)
          {
            :type => :annotation,
            :href => "#{base_url}/api/annotations/#{id}"
          }
        end

        def link_collection
          {
            :type => :annotation_collection,
            :href => "#{base_url}/api/annotations"
          }
        end
      end

      class AnnotationCollectionSerializer < BaseSerializer
        adapter Oat::Adapters::HAL
        schema do
          type     :annotation_collection
          property :annotation_collection, item
          link     :self,                  link_self
          link     :start,                 link_start
        end

        private

        def link_self
          {
            :type => :annotation_collection,
            :href => "#{base_url}/api/annotations"
          }
        end

        def link_start
          {
            :type => :start,
            :href => "#{base_url}/api/annotations/values"
          }
        end
      end

      class AnnotationValueSerializer < BaseSerializer
        adapter Oat::Adapters::HAL
        schema do
          type     :annotation_value
          property :type,            item.type ? item.type.sub(VOCABULARY_RDF, '') : nil
          property :identifier,      item.identifier
          property :name,            item.prefLabel
          setup(item)
          link     :self,            link_self
          link     :collection,      link_annotation
        end

        private

        def setup(item)
          @annotation_id, @annotation_value_id = URI(item.uri).path.split('/')[3..-1]
        end

        def link_self
          {
            :type => :annotation_value,
            :href => "#{base_url}/api/annotations/#{@annotation_id}/values/#{@annotation_value_id}"
          }
        end

        def link_annotation
          {
            :type => :annotation,
            :href => "#{base_url}/api/annotations/#{@annotation_id}"
          }
        end
      end

      class AnnotationValueResourceSerializer < BaseSerializer
        adapter Oat::Adapters::HAL
        schema do
          type     :annotation_value
          property :annotation_value, item
        end
      end

      class AnnotationValueCollectionSerializer < BaseSerializer
        adapter Oat::Adapters::HAL
        schema do
          type     :annotation_value_collection
          property :annotation_value_collection, item
        end
      end
    end
  end
end
