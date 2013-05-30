require 'mongoid'
require 'csv'

module MongoidToCSV

  # Return full CSV content with headers as string.
  # Defined as class method which will have chained scopes applied.
  def to_csv
    documents_to_csv all
  end

  module_function

  def documents_to_csv(documents, fields = nil)
    return documents.to_csv unless documents.first.class.respond_to? :fields
    
    fields ||= documents.first.class.fields.keys
    
    doc_class = documents.first.class
    csv_columns = fields - %w{_id created_at updated_at _type}
    header_row = csv_columns.to_csv
    records_rows = documents.map do |record|
      csv_columns.map do |column|
        value = if column.include? '.'
          column.split('.').reduce(record) {|r, method| r.send(method) }
        else
          record.send(column)
        end
        
        if value.respond_to?(:to_csv)
          value = value.to_csv
          value.gsub! /\n$/, '' if array_type_for_record(record, column)
        else
          value.to_s
        end

        value
      end.to_csv
    end.join
    header_row + records_rows
  end

  private

  def array_type_for_record record, column
    embed_list = column.split('.')
    field = embed_list.pop
    instance = embed_list.reduce(record) {|r, method| r.send(method) }
    instance.class.fields[field].type == Array
  end

end

module Mongoid::Document
  def self.included(target)
    target.extend MongoidToCSV
  end
end

# Define Relation#to_csv so that method_missing will not
# delegate to array.
class Mongoid::Relation
  def to_csv
    scoping do
      @klass.to_csv
    end
  end
end

class Array
  def mongoid_to_csv
    return self if empty?
    MongoidToCSV.documents_to_csv(self)
  end
end
