module Qbxml::Types
  XML_DIRECTIVES = {
    qb: :qbxml,
    qbpos: :qbposxml
  }.freeze

  FLOAT_CAST = proc { |d| d ? Float(d) : 0.0 }
  BOOL_CAST  = proc { |d| d && d.to_s.downcase == 'true' }
  DATE_CAST  = proc { |d| d ? Date.parse(d).strftime('%Y-%m-%d') : Date.today.strftime('%Y-%m-%d') }
  TIME_CAST  = proc { |d| d ? Time.parse(d).xmlschema : Time.now.xmlschema }
  INT_CAST   = proc { |d| d ? Integer(d.to_i) : 0 }
  STR_CAST   = proc { |d| d ? String(d) : '' }
  BIGDECIMAL_CAST   = proc { |d| d ? BigDecimal.new(d) : 0.0 }

  TYPE_MAP = {
    'AMTTYPE'          => FLOAT_CAST,
    'BOOLTYPE'         => BOOL_CAST,
    'DATETIMETYPE'     => TIME_CAST,
    'DATETYPE'         => DATE_CAST,
    'ENUMTYPE'         => STR_CAST,
    'FLOATTYPE'        => FLOAT_CAST,
    'GUIDTYPE'         => STR_CAST,
    'IDTYPE'           => STR_CAST,
    'INTTYPE'          => INT_CAST,
    'PERCENTTYPE'      => FLOAT_CAST,
    'PRICETYPE'        => FLOAT_CAST,
    'QUANTYPE'         => BIGDECIMAL_CAST,
    'STRTYPE'          => STR_CAST,
    'TIMEINTERVALTYPE' => STR_CAST
  }

  # Strings in tag names that should be capitalized in QB's XML
  ACRONYMS = %w(AP AR COGS COM UOM QBXML UI AVS ID PIN SSN COM CLSID FOB EIN UOM PO PIN QB)

  # Based on the regexp in ActiveSupport::Inflector.camelize
  # Substring 1: Start of string, lower case letter, or slash
  # Substring 2: One of the acronyms above, In Capitalized Casing
  # Substring 3: End of string or capital letter
  ACRONYM_REGEXP = Regexp.new("(?:(^|[a-z]|\\/))(#{ACRONYMS.map(&:capitalize).join('|')})([A-Z]|$)")
end
