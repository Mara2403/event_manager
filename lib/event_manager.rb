require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

# clean phone number
def clean_phone_number(phone_num)
  phone_number = phone_num.gsub(/[^0-9]/, '')

  if phone_number.length < 10 || phone_number.length > 11
    return nil
  elsif phone_number.length == 11
    phone_number[0] == '1' ? phone_number.slice!(0) : nil
  end

  phone_number
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

regdate_strings = []
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone_number(row[:homephone])
  registration_by_hour = row[:regdate]
  regdate_strings << registration_by_hour

  if phone
    puts "#{name} #{zipcode} #{phone}"
  else
    puts "#{name} #{zipcode} Invalid phone number"
  end
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

date_times = regdate_strings.map { |date_time| DateTime.strptime(date_time, '%m/%d/%y %H:%M') }
# for the check up, to manually count it and see is it is true
# date_times.each do |date_time|
#   puts date_time.strftime("%A")
# end

grouped_by_day = date_times.group_by { |dt| dt.strftime('%A') }

# Find the maximum number of registrations
max_registrations = grouped_by_day.values.map(&:length).max

# Find all days with the maximum number of registrations by day
most_common_days = grouped_by_day.select { |_, dates| dates.length == max_registrations }.keys

# Output the most common days
puts "The most common registration day of the week is: #{most_common_days.map(&:capitalize).join(', ')}."

# Similar by hour
grouped_by_hour = date_times.group_by { |hour| hour.strftime('%H') }

max_registrations = grouped_by_hour.values.map(&:length).max

most_common_hours = grouped_by_hour.select { |_, hour| hour.length == max_registrations }.keys

puts "The most common registration hour is: #{most_common_hours.map(&:capitalize).join(', ')}."
