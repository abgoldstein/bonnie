class ValueSet < CodeSet
  include Mongoid::Document
  
  field :key, type: String
  field :concept, type: String
  field :oid, type: String
  field :category, type: String
  field :description, type: String
  field :organization, type: String
  field :version, type: String
  embeds_many :code_sets, class_name: "CodeSet", inverse_of: :parent
  
  # diagnosis_condition_problem
  Categories = %w(
    encounter
    procedure
    risk_category_assessment
    communication
    laboratory_test
    physical_exam
    medication
    condition_diagnosis_problem
    diagnosis_condition_problem
    symptom
    individual_characteristic
    device
    care_goal
    diagnostic_study
    substance
    attribute
    intervention
    result
  )
  
  validates_inclusion_of :category, in: Categories
  validates_format_of :oid, with: /^[\d*\.\d]+$/
  
end
