class CsvNormalizer
  require 'csv'

  def initialize(input)
    @input = input
  end

  def normalize
    # replace invalid UTF-8 characters with Unicode Replacement Character
    input = @input.scrub

    # Ruby's CSV objects give us a lot of helpful methods,
    # but I'm having trouble getting it to create CSV objects from a string.
    # So, as a hack, create a temp file for CSV to read.
    filename = 'temp.csv'
    file = File.new('temp.csv', 'w+')
    file.write(input)
    file.close

    # Ok, nice.  Now we can easily process the rows.
    csv = CSV.read(filename, headers: true, encoding: 'UTF-8').each do |row|
      row['Timestamp'] = convert_to_EST(row['Timestamp'])
      row['ZIP'] = enforce_length(row['ZIP'])
      row['FullName'].upcase!
      row['FooDuration'] = time_to_seconds(row['FooDuration'])
      row['BarDuration'] = time_to_seconds(row['BarDuration'])
      row['TotalDuration'] = row['FooDuration'] + row['BarDuration']
    end

    # clean up the temp file
    File.delete(filename)

    csv
  end

  private

  def time_to_seconds(time_str)
    hours, minutes, seconds = time_str.split(":").map{|str| str.to_i}
    milliseconds = "0.#{time_str.split('.').last}".to_f
    (hours * 60 + minutes) * 60 + seconds + milliseconds
  end

  def zero_prefix(str)
    str.insert(0, '0')
  end

  def convert_to_EST(time_str)
    # convert the CSV's dates into a format that Ruby can consume
    time_ary = time_str.split('/')
    time_ary.first(2).each { |n| n = zero_prefix(n) if n.length == 1 }
    time_str = time_ary.join('/').concat(' -08:00')

    # consume the date
    date_time = DateTime.strptime(time_str, "%m/%d/%y %I:%M:%S %p %z")

    # convert it to EST and output in the original format
    date_time.to_time.getlocal('-05:00').strftime("%-m/%-d/%y %I:%M:%S %p")
  end

  def enforce_length(zip)
    # Add zeroes to the beginning of a string until it's 5 digits long.
    while zip.length < 5 do
      zero_prefix(zip)
    end
    zip
  end
end

$stdout.puts CsvNormalizer.new(ARGF.read).normalize
