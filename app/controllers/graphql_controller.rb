# frozen_string_literal: true

class GraphqlController < ApplicationController
  # Skip CSRF token verification for API requests
  skip_before_action :verify_authenticity_token

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user
    }

    result = KohaiGameWeb3Schema.execute(
      query,
      variables: variables,
      context: context,
      operation_name: operation_name
    )

    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def current_user
    return nil unless auth_token.present?

    @current_user ||= SolanaAuthService.verify_token(auth_token)
  end

  def auth_token
    # Extract token from Authorization header
    # Format: "Bearer <token>"
    authorization_header = request.headers['Authorization']
    return nil unless authorization_header.present?

    authorization_header.split(' ').last
  end

  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: {
      errors: [
        {
          message: e.message,
          backtrace: e.backtrace
        }
      ],
      data: {}
    }, status: 500
  end
end
