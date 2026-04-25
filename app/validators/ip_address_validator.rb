# Validates that a value is a plain IP address (IPv4 or IPv6).
# Uses IPAddr for broad protocol support, then rejects formats that
# IPAddr accepts but request.remote_ip will never produce (CIDR notation, zone IDs).
class IpAddressValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    if value.include?("/") || value.include?("%")
      record.errors.add(attribute, "must be a valid IP address")
      return
    end

    IPAddr.new(value)
  rescue IPAddr::InvalidAddressError
    record.errors.add(attribute, "must be a valid IP address")
  end
end
