# XML Conversion References
#
# https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/conversions.rb
# https://github.com/rails/rails/blob/master/activesupport/lib/active_support/xml_mini/nokogiri.rb
#
#
class Qbxml::Hash < ::Hash
  include Qbxml::Types

  CONTENT_ROOT = '__content__'.freeze
  ATTR_ROOT    = 'xml_attributes'.freeze
  IGNORED_KEYS = [ATTR_ROOT]

  def self.from_hash(hash, opts = {}, &_block)
    key_proc = \
      if opts[:camelize]
        lambda do |k|
          # QB wants things like ListID, not ListId. Adding inflections then using camelize can accomplish
          # the same thing, but then the inflections will apply to everything the user does everywhere.
          k.camelize.gsub(Qbxml::Types::ACRONYM_REGEXP) { "#{Regexp.last_match(1)}#{Regexp.last_match(2).upcase}#{Regexp.last_match(3)}" }
        end
      elsif opts[:underscore]
        ->(k) { k.underscore }
      end

    deep_convert(hash, opts, &key_proc)
  end

  def to_xml(opts = {})
    self.class.to_xml(self, opts)
  end

  def self.to_xml(hash, opts = {})
    opts[:root], hash = hash.first
    opts[:attributes] = hash.delete(ATTR_ROOT)
    hash_to_xml(hash, opts)
  end

  def self.from_xml(xml, opts = {})
    from_hash(
      xml_to_hash(Nokogiri::XML(xml).root, {}, opts), opts)
  end

  def self.hash_to_xml(hash, opts = {})
    opts = opts.dup
    opts[:indent] ||= 2
    opts[:root] ||= :hash
    opts[:attributes] ||= (hash.delete(ATTR_ROOT) || {})
    opts[:builder] ||= Builder::XmlMarkup.new(indent: opts[:indent])
    opts[:skip_types]      = true unless opts.key?(:skip_types)
    opts[:skip_instruct]   = false unless opts.key?(:skip_instruct)
    builder = opts[:builder]

    unless opts.delete(:skip_instruct)
      builder.instruct!(:xml, encoding: 'ISO-8859-1')
      builder.instruct!(opts[:schema], version: opts[:version])
    end

    builder.tag!(opts[:root], opts.delete(:attributes)) do
      hash.each do |key, val|
        case val
        when Hash
          hash_to_xml(val, opts.merge(root: key, skip_instruct: true))
        when Array
          val.map do |i|
            next builder.tag!(key, i, {}) if i.is_a?(String)
            next hash_to_xml(i, opts.merge(root: key, skip_instruct: true))
          end
        else
          builder.tag!(key, val, {})
        end
      end

      yield builder if block_given?
    end
  end

  def self.xml_to_hash(node, hash = {}, opts = {})
    node_hash = { CONTENT_ROOT => '', ATTR_ROOT => {} }
    name = node.name
    schema = opts[:schema]
    opts[:typecast_cache] ||= {}

    # Insert node hash into parent hash correctly.
    case hash[name]
    when Array
      hash[name] << node_hash
    when Hash, String
      hash[name] = [hash[name], node_hash]
    else
      hash[name] = node_hash
    end

    # Handle child elements
    node.children.each do |c|
      if c.element?
        xml_to_hash(c, node_hash, opts)
      elsif c.text? || c.cdata?
        node_hash[CONTENT_ROOT] << c.content
      end
    end

    # Handle attributes
    node.attribute_nodes.each { |a| node_hash[ATTR_ROOT][a.node_name] = a.value }

    # TODO: Strip text
    # node_hash[CONTENT_ROOT].strip!

    # Format node
    if node_hash.size > 2 || node_hash[ATTR_ROOT].present?
      node_hash.delete(CONTENT_ROOT)
    elsif node_hash[CONTENT_ROOT].present?
      node_hash.delete(ATTR_ROOT)
      v = schema ? typecast(schema, node.path, node_hash[CONTENT_ROOT], opts[:typecast_cache]) : node_hash[CONTENT_ROOT]
      # We only updated the last element
      if hash[name].is_a?(Array)
        hash[name].pop
        hash[name] << v
      else
        hash[name] = v
      end
    else
      hash[name] = node_hash[CONTENT_ROOT]
    end

    hash
  end

  def self.typecast(schema, xpath, value, typecast_cache)
    type_path = xpath.gsub(/\[\d+\]/, '')
    # This is fairly expensive. Cache it for better performance when parsing lots of records of the same type.
    type_proc = typecast_cache[type_path] ||= Qbxml::TYPE_MAP[schema.xpath(type_path).first.try(:text)]
    fail "#{xpath} is not a valid type" unless type_proc
    type_proc[value]
  end

  def self.deep_convert(hash, _opts = {}, &block)
    hash.each_with_object(new) do |(k, v), h|
      k = k.to_s
      ignored = IGNORED_KEYS.include?(k)
      if ignored
        h[k] = v
      else
        key = block_given? ? yield(k) : k
        h[key] = \
          case v
          when Hash
            deep_convert(v, &block)
          when Array
            v.map { |i| i.is_a?(Hash) ? deep_convert(i, &block) : i }
          else v
          end
      end; h
    end
  end
end
