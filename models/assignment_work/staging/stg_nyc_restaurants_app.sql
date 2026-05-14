-- Clean and standardize NYC restaurant application data
-- One row per restaurant application

WITH source AS (

    SELECT *
    FROM {{ source('raw', 'source_open_restaurants_application_historic') }}

),

cleaned AS (

    SELECT

        -- Exclude columns we are transforming
        * EXCEPT (
            objectid,
            restaurant_name,
            applicant,
            doing_business_as_dba,
            boro,
            building,
            street,
            zip,
            food_service_establishment,
            seating_interest_sidewalk,
            approved_for_sidewalk_seating,
            approved_for_roadway_seating,
            qualify_alcohol,
            sla_serial_number,
            sla_license_type,
            landmark_district_or_building,
            landmark_status,
            healthcompliance,
            time_of_submission,
            latitude,
            longitude,
            borough,
            bulding_number,
            business_address
        ),

        -- Identifiers
        CAST(objectid AS STRING) AS application_id,

        -- Restaurant details
        TRIM(CAST(restaurant_name AS STRING)) AS restaurant_name,
        TRIM(CAST(applicant AS STRING)) AS applicant_name,
        TRIM(CAST(doing_business_as_dba AS STRING)) AS dba_name,

        -- Borough standardization
        CASE
            WHEN UPPER(TRIM(boro)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(boro)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(boro)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(boro)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(boro)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- Address information
        CAST(building AS STRING) AS building_number,
        CAST(street AS STRING) AS street_name,

        CONCAT(
            COALESCE(CAST(building AS STRING), ''),
            ' ',
            COALESCE(CAST(street AS STRING), '')
        ) AS full_address,

        -- ZIP code cleaning
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
            WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
            WHEN LENGTH(CAST(zip AS STRING)) = 10
                AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}$')
            THEN CAST(zip AS STRING)
            ELSE NULL
        END AS zip_code,

        -- Restaurant characteristics
        UPPER(TRIM(CAST(food_service_establishment AS STRING)))
            AS food_service_establishment,

        UPPER(TRIM(CAST(seating_interest_sidewalk AS STRING)))
            AS seating_interest_sidewalk,

        -- Seating dimensions
        CAST(sidewalk_dimensions_length AS FLOAT64)
            AS sidewalk_length_ft,

        CAST(sidewalk_dimensions_width AS FLOAT64)
            AS sidewalk_width_ft,

        CAST(sidewalk_dimensions_area AS FLOAT64)
            AS sidewalk_area_sqft,

        CAST(roadway_dimensions_length AS FLOAT64)
            AS roadway_length_ft,

        CAST(roadway_dimensions_width AS FLOAT64)
            AS roadway_width_ft,

        CAST(roadway_dimensions_area AS FLOAT64)
            AS roadway_area_sqft,

        -- Approvals
        UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING)))
            AS approved_sidewalk_seating,

        UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING)))
            AS approved_roadway_seating,

        -- Alcohol licensing
        UPPER(TRIM(CAST(qualify_alcohol AS STRING)))
            AS qualify_alcohol,

        CAST(sla_serial_number AS STRING) AS sla_serial_number,
        CAST(sla_license_type AS STRING) AS sla_license_type,

        -- Landmark information
        UPPER(TRIM(CAST(landmark_district_or_building AS STRING)))
            AS landmark_district_or_building,

        UPPER(TRIM(CAST(landmark_status AS STRING)))
            AS landmark_status,

        -- Health compliance
        UPPER(TRIM(CAST(healthcompliance AS STRING)))
            AS health_compliance,

        -- Submission timestamp
        CAST(time_of_submission AS TIMESTAMP)
            AS submitted_at,

        -- Geographic coordinates
        CAST(latitude AS FLOAT64) AS latitude,
        CAST(longitude AS FLOAT64) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
      AND restaurant_name IS NOT NULL
      AND time_of_submission IS NOT NULL

    -- Deduplicate
    QUALIFY ROW_NUMBER()
        OVER (
            PARTITION BY objectid
            ORDER BY time_of_submission DESC
        ) = 1

)

SELECT *
FROM cleaned