-- =============================================================================
-- Roma Segreta — RPC function for booking upsert
-- Bypasses PostgREST column resolution issues
-- =============================================================================

-- Drop if exists
DROP FUNCTION IF EXISTS upsert_bookings(jsonb);

CREATE OR REPLACE FUNCTION upsert_bookings(bookings_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  row_data jsonb;
  total_count int := 0;
BEGIN
  FOR row_data IN SELECT jsonb_array_elements(bookings_data)
  LOOP
    INSERT INTO bookings (
      lodgify_booking_id, property_id, guest_name, guest_email, guest_phone,
      num_guests, checkin_date, checkout_date, status, source, 
      total_amount, synced_at
    ) VALUES (
      (row_data->>'lodgify_booking_id')::int,
      (row_data->>'property_id')::uuid,
      row_data->>'guest_name',
      row_data->>'guest_email',
      row_data->>'guest_phone',
      COALESCE((row_data->>'num_guests')::smallint, 2),
      (row_data->>'checkin_date')::date,
      (row_data->>'checkout_date')::date,
      COALESCE(row_data->>'status', 'confirmed'),
      row_data->>'source',
      (row_data->>'total_amount')::numeric,
      COALESCE((row_data->>'synced_at')::timestamptz, now())
    )
    ON CONFLICT (lodgify_booking_id) DO UPDATE SET
      property_id = EXCLUDED.property_id,
      guest_name = EXCLUDED.guest_name,
      guest_email = EXCLUDED.guest_email,
      guest_phone = EXCLUDED.guest_phone,
      num_guests = EXCLUDED.num_guests,
      checkin_date = EXCLUDED.checkin_date,
      checkout_date = EXCLUDED.checkout_date,
      status = EXCLUDED.status,
      source = EXCLUDED.source,
      total_amount = EXCLUDED.total_amount,
      synced_at = EXCLUDED.synced_at;
    
    total_count := total_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object('synced', total_count);
END;
$$;

-- Grant execute to service_role (used by Edge Functions)
GRANT EXECUTE ON FUNCTION upsert_bookings(jsonb) TO service_role;
-- Also grant to authenticated for direct API calls
GRANT EXECUTE ON FUNCTION upsert_bookings(jsonb) TO authenticated;
