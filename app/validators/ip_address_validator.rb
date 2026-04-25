class IpAddressValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    IPAddr.new(value)
  rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
    record.errors.add(attribute, "must be a valid IP address")
  end
end
