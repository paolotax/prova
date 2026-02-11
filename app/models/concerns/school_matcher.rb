require "fuzzy_match"

module SchoolMatcher
  extend ActiveSupport::Concern

  def find_matching_school(text, user_id)
    schools = Current.account.scuole
    schools_data = schools.map { |school|
      [school.to_combobox_display, school.id]
    }.to_h

    return nil if schools_data.empty?

    matcher = FuzzyMatch.new(schools_data.keys)
    matched_full_name = matcher.find(text)

    return {
      name: matched_full_name,
      import_scuola_id: schools_data[matched_full_name]
    } if matched_full_name

    nil
  end
end
