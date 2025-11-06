{{
    config(
        materialized = 'table'
    )
}}

with

prep_research_study_bill_group_source as (

    select
        hospital_transaction_key,
        tx_id,
        patient_hospital_account_id,
        research_hospital_account_id,
        research_study_bill_group
    from {{ ref('prep_research_study_bill_group') }}

),

unified_billing_transactions_source as (

    select
        billing_transaction_key,
        billing_module,
        amount,
        quantity,
        transaction_type,
        epic_hospital_account_id,
        epic_professional_tx_id,
        revenue_code,
        transaction_billing_code,
        medical_foundation_cpt_subgroup,
        cost_center,
        is_em_charge,
        billing_procedure_code
    from {{ ref('ae_enterprise_dbt', 'unified_billing_transactions') }}
    where not _is_deleted_in_source

),

professional_transactions_source as (

    select
        epic_professional_tx_id,
        place_of_service_type_code,
        modifiers,
        case
            when modifiers is not null and array_position(modifiers, '95') is not null then true
            else false
        end as has_modifier_95
    from {{ ref('ae_enterprise_dbt', 'professional_transactions') }}
    where not _is_deleted_in_source

),

research_account_metrics as (

    select
        prep_research_study_bill_group_source.patient_hospital_account_id,
        prep_research_study_bill_group_source.research_hospital_account_id,
        sum(
            case
                when lower(unified_billing_transactions_source.billing_module) = 'hospital'
                    then coalesce(unified_billing_transactions_source.quantity, 0)
                else 0
            end
        ) as total_transaction_quantity
    from prep_research_study_bill_group_source
    left join unified_billing_transactions_source
        on prep_research_study_bill_group_source.hospital_transaction_key = unified_billing_transactions_source.billing_transaction_key
    where prep_research_study_bill_group_source.research_study_bill_group in (
        'Study, Bill to Research Sponsor',
        'Study, Bill to Insurance (Routine)'
    )
    group by
        prep_research_study_bill_group_source.patient_hospital_account_id,
        prep_research_study_bill_group_source.research_hospital_account_id
    having sum(
        case
            when lower(unified_billing_transactions_source.billing_module) = 'hospital'
                then coalesce(unified_billing_transactions_source.quantity, 0)
            else 0
        end
    ) > 0

),

eligible_research_transactions as (

    select distinct
        prep_research_study_bill_group_source.hospital_transaction_key,
        prep_research_study_bill_group_source.tx_id,
        prep_research_study_bill_group_source.patient_hospital_account_id,
        prep_research_study_bill_group_source.research_hospital_account_id
    from prep_research_study_bill_group_source
    inner join research_account_metrics
        on prep_research_study_bill_group_source.patient_hospital_account_id = research_account_metrics.patient_hospital_account_id
        and prep_research_study_bill_group_source.research_hospital_account_id = research_account_metrics.research_hospital_account_id

),

research_account_to_patient as (

    select distinct
        eligible_research_transactions.patient_hospital_account_id,
        eligible_research_transactions.research_hospital_account_id
    from eligible_research_transactions

),

research_patient_account_list as (

    select
        research_account_metrics.patient_hospital_account_id,
        listagg(
            research_account_metrics.research_hospital_account_id,
            ' | '
        ) within group (order by research_account_metrics.research_hospital_account_id) as hospital_account_id_research
    from research_account_metrics
    group by research_account_metrics.patient_hospital_account_id

),

research_billing_transactions as (

    select
        research_account_to_patient.patient_hospital_account_id,
        research_account_to_patient.research_hospital_account_id,
        unified_billing_transactions_source.billing_module,
        unified_billing_transactions_source.amount,
        unified_billing_transactions_source.quantity,
        unified_billing_transactions_source.transaction_type,
        unified_billing_transactions_source.revenue_code,
        unified_billing_transactions_source.transaction_billing_code,
        unified_billing_transactions_source.medical_foundation_cpt_subgroup,
        unified_billing_transactions_source.cost_center,
        unified_billing_transactions_source.is_em_charge,
        unified_billing_transactions_source.billing_procedure_code,
        unified_billing_transactions_source.epic_professional_tx_id
    from unified_billing_transactions_source
    inner join research_account_to_patient
        on unified_billing_transactions_source.epic_hospital_account_id = research_account_to_patient.research_hospital_account_id
    where lower(unified_billing_transactions_source.transaction_type) = 'charge'

),

research_billing_transactions_enriched as (

    select
        research_billing_transactions.patient_hospital_account_id,
        research_billing_transactions.research_hospital_account_id,
        research_billing_transactions.billing_module,
        research_billing_transactions.amount,
        research_billing_transactions.quantity,
        research_billing_transactions.transaction_type,
        research_billing_transactions.revenue_code,
        research_billing_transactions.transaction_billing_code,
        research_billing_transactions.medical_foundation_cpt_subgroup,
        research_billing_transactions.cost_center,
        research_billing_transactions.is_em_charge,
        research_billing_transactions.billing_procedure_code,
        research_billing_transactions.epic_professional_tx_id,
        professional_transactions_source.place_of_service_type_code,
        professional_transactions_source.has_modifier_95
    from research_billing_transactions
    left join professional_transactions_source
        on research_billing_transactions.epic_professional_tx_id = professional_transactions_source.epic_professional_tx_id

),

research_billing_transactions_metrics as (

    select
        research_billing_transactions_enriched.patient_hospital_account_id,
        research_billing_transactions_enriched.research_hospital_account_id,
        research_billing_transactions_enriched.quantity,
        research_billing_transactions_enriched.amount,
        research_billing_transactions_enriched.billing_module,
        research_billing_transactions_enriched.revenue_code,
        try_to_number(research_billing_transactions_enriched.revenue_code) as revenue_code_number,
        research_billing_transactions_enriched.transaction_billing_code,
        research_billing_transactions_enriched.medical_foundation_cpt_subgroup,
        research_billing_transactions_enriched.cost_center,
        research_billing_transactions_enriched.is_em_charge,
        research_billing_transactions_enriched.billing_procedure_code,
        research_billing_transactions_enriched.place_of_service_type_code,
        research_billing_transactions_enriched.has_modifier_95,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and try_to_number(research_billing_transactions_enriched.revenue_code) between 110 and 219
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as inpatient_room_quantity,
        case
            when research_billing_transactions_enriched.is_em_charge then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as em_inperson_quantity,
        case
            when research_billing_transactions_enriched.is_em_charge
                and coalesce(research_billing_transactions_enriched.amount, 0) <> 0
                then sign(coalesce(research_billing_transactions_enriched.quantity, 0))
            else 0
        end as em_inperson_transaction_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0780'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            when upper(research_billing_transactions_enriched.billing_module) = 'PROFESSIONAL'
                and (
                    research_billing_transactions_enriched.place_of_service_type_code = '2'
                    or research_billing_transactions_enriched.has_modifier_95
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as em_virtual_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0780'
                and coalesce(research_billing_transactions_enriched.amount, 0) <> 0
                then sign(coalesce(research_billing_transactions_enriched.quantity, 0))
            when upper(research_billing_transactions_enriched.billing_module) = 'PROFESSIONAL'
                and (
                    research_billing_transactions_enriched.place_of_service_type_code = '2'
                    or research_billing_transactions_enriched.has_modifier_95
                )
                and coalesce(research_billing_transactions_enriched.amount, 0) <> 0
                then sign(coalesce(research_billing_transactions_enriched.quantity, 0))
            else 0
        end as em_virtual_transaction_quantity,
        case
            when research_billing_transactions_enriched.transaction_billing_code in (
                '96409', '96413', '96416', '96360', '96365', '96374'
            )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as infusion_chemo_quantity,
        case
            when research_billing_transactions_enriched.transaction_billing_code in ('96360', '96365', '96374')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as infusion_quantity,
        case
            when research_billing_transactions_enriched.transaction_billing_code in ('96409', '96413', '96416')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as chemo_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code between '0300' and '0309'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as labs_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code between '0310' and '0319'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as pathology_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code between '0350' and '0359'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_ct_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code between '0610' and '0614'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_mri_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code between '0615' and '0618'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_mra_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0404'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_pet_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0402'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_ultrasound_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code in ('0320', '0324')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_x_ray_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0401'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_mammography_diagnostic_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0403'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_mammography_screening_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code in ('0341', '0342')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_nuclear_medicine_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and (
                    research_billing_transactions_enriched.revenue_code in ('0320', '0324', '0341', '0342')
                    or research_billing_transactions_enriched.revenue_code between '0350' and '0359'
                    or research_billing_transactions_enriched.revenue_code between '0401' and '0404'
                    or research_billing_transactions_enriched.revenue_code between '0610' and '0614'
                    or research_billing_transactions_enriched.revenue_code between '0615' and '0618'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            when upper(research_billing_transactions_enriched.billing_module) = 'PROFESSIONAL'
                and upper(research_billing_transactions_enriched.medical_foundation_cpt_subgroup) in (
                    'CT', 'CT SCAN', 'CT SIMULATION', 'MRA', 'MRI', 'PET/CT',
                    'ULTRASOUND', 'RADIOLOGY', 'MAMMOGRAPHY', 'NUCLEAR MEDICINE'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as imaging_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0762'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as observation_hours_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.transaction_billing_code in (
                    '0182T','77372','77373','77385','77386','77402','77403','77404',
                    '77407','77408','77409','77412','77413','77414','77418','77785',
                    '77786','77787','77770','77771','77772','0395T'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            when upper(research_billing_transactions_enriched.billing_module) = 'PROFESSIONAL'
                and (
                    research_billing_transactions_enriched.transaction_billing_code in (
                        '77401','77402','77407','77412','77750','77767','77768','77778','77789'
                    )
                    or research_billing_transactions_enriched.transaction_billing_code between '0394T' and '0395T'
                    or research_billing_transactions_enriched.transaction_billing_code between '77371' and '77373'
                    or research_billing_transactions_enriched.transaction_billing_code between '77385' and '77386'
                    or research_billing_transactions_enriched.transaction_billing_code between '77424' and '77425'
                    or research_billing_transactions_enriched.transaction_billing_code between '77600' and '77620'
                    or research_billing_transactions_enriched.transaction_billing_code between '77761' and '77763'
                    or research_billing_transactions_enriched.transaction_billing_code between '77770' and '77772'
                    or research_billing_transactions_enriched.transaction_billing_code between 'G6003' and 'G6016'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_delivery_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.revenue_code = '0333'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            when upper(research_billing_transactions_enriched.billing_module) = 'PROFESSIONAL'
                and (
                    research_billing_transactions_enriched.transaction_billing_code between '0394T' and '0395T'
                    or research_billing_transactions_enriched.transaction_billing_code between '77261' and '77299'
                    or research_billing_transactions_enriched.transaction_billing_code between '77371' and '77799'
                    or research_billing_transactions_enriched.transaction_billing_code between 'G6003' and 'G6016'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.billing_procedure_code in (
                    '33300412','33307401','33307402','33307412','33377403','33377412','33377414'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_3d_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.billing_procedure_code in (
                    '33300386','33307384','33307385','33307386','33377385','33377386','33377389','33377391'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_imrt_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.billing_procedure_code in ('33377372','33377374')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_srs_sbrt_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.billing_procedure_code in ('33377770','33377771','33377772')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_hdr_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.billing_procedure_code = '33377424'
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as rad_onc_iort_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.billing_procedure_code in (
                    '36000001','36000002','36000003','36000004','36000005','36000024','36120660'
                )
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as surgery_one_hour_quantity,
        case
            when upper(research_billing_transactions_enriched.billing_module) = 'HOSPITAL'
                and research_billing_transactions_enriched.cost_center in ('7509000', '7640005')
                and research_billing_transactions_enriched.transaction_billing_code in ('36591', '36592')
                then coalesce(research_billing_transactions_enriched.quantity, 0)
            else 0
        end as vad_quantity
    from research_billing_transactions_enriched

),

final as (

    select
        research_billing_transactions_metrics.patient_hospital_account_id as hospital_account_id_patient,
        research_patient_account_list.hospital_account_id_research,
        sum(research_billing_transactions_metrics.inpatient_room_quantity) as inpatient_room_quantity,
        sum(research_billing_transactions_metrics.em_inperson_quantity) as em_inperson_quantity,
        sum(research_billing_transactions_metrics.em_inperson_transaction_quantity) as em_inperson_transaction_quantity,
        sum(research_billing_transactions_metrics.em_virtual_quantity) as em_virtual_quantity,
        sum(research_billing_transactions_metrics.em_virtual_transaction_quantity) as em_virtual_transaction_quantity,
        sum(research_billing_transactions_metrics.infusion_chemo_quantity) as infusion_chemo_quantity,
        sum(research_billing_transactions_metrics.infusion_quantity) as infusion_quantity,
        sum(research_billing_transactions_metrics.chemo_quantity) as chemo_quantity,
        sum(research_billing_transactions_metrics.labs_quantity) as labs_quantity,
        sum(research_billing_transactions_metrics.pathology_quantity) as pathology_quantity,
        sum(research_billing_transactions_metrics.imaging_ct_quantity) as imaging_ct_quantity,
        sum(research_billing_transactions_metrics.imaging_mri_quantity) as imaging_mri_quantity,
        sum(research_billing_transactions_metrics.imaging_mra_quantity) as imaging_mra_quantity,
        sum(research_billing_transactions_metrics.imaging_pet_quantity) as imaging_pet_quantity,
        sum(research_billing_transactions_metrics.imaging_ultrasound_quantity) as imaging_ultrasound_quantity,
        sum(research_billing_transactions_metrics.imaging_x_ray_quantity) as imaging_x_ray_quantity,
        sum(research_billing_transactions_metrics.imaging_mammography_diagnostic_quantity) as imaging_mammography_diagnostic_quantity,
        sum(research_billing_transactions_metrics.imaging_mammography_screening_quantity) as imaging_mammography_screening_quantity,
        sum(research_billing_transactions_metrics.imaging_nuclear_medicine_quantity) as imaging_nuclear_medicine_quantity,
        sum(research_billing_transactions_metrics.imaging_quantity) as imaging_quantity,
        sum(research_billing_transactions_metrics.observation_hours_quantity) as observation_hours_quantity,
        sum(research_billing_transactions_metrics.rad_onc_delivery_quantity) as rad_onc_delivery_quantity,
        sum(research_billing_transactions_metrics.rad_onc_quantity) as rad_onc_quantity,
        sum(research_billing_transactions_metrics.rad_onc_3d_quantity) as rad_onc_3d_quantity,
        sum(research_billing_transactions_metrics.rad_onc_imrt_quantity) as rad_onc_imrt_quantity,
        sum(research_billing_transactions_metrics.rad_onc_srs_sbrt_quantity) as rad_onc_srs_sbrt_quantity,
        sum(research_billing_transactions_metrics.rad_onc_hdr_quantity) as rad_onc_hdr_quantity,
        sum(research_billing_transactions_metrics.rad_onc_iort_quantity) as rad_onc_iort_quantity,
        sum(research_billing_transactions_metrics.surgery_one_hour_quantity) as surgery_one_hour_quantity,
        sum(research_billing_transactions_metrics.vad_quantity) as vad_quantity,
        current_timestamp() as update_dtm
    from research_billing_transactions_metrics
    inner join research_patient_account_list
        on research_billing_transactions_metrics.patient_hospital_account_id = research_patient_account_list.patient_hospital_account_id
    group by
        research_billing_transactions_metrics.patient_hospital_account_id,
        research_patient_account_list.hospital_account_id_research

)

select
    hospital_account_id_patient,
    hospital_account_id_research,
    inpatient_room_quantity,
    em_inperson_quantity,
    em_inperson_transaction_quantity,
    em_virtual_quantity,
    em_virtual_transaction_quantity,
    infusion_chemo_quantity,
    infusion_quantity,
    chemo_quantity,
    labs_quantity,
    pathology_quantity,
    imaging_ct_quantity,
    imaging_mri_quantity,
    imaging_mra_quantity,
    imaging_pet_quantity,
    imaging_ultrasound_quantity,
    imaging_x_ray_quantity,
    imaging_mammography_diagnostic_quantity,
    imaging_mammography_screening_quantity,
    imaging_nuclear_medicine_quantity,
    imaging_quantity,
    observation_hours_quantity,
    rad_onc_delivery_quantity,
    rad_onc_quantity,
    rad_onc_3d_quantity,
    rad_onc_imrt_quantity,
    rad_onc_srs_sbrt_quantity,
    rad_onc_hdr_quantity,
    rad_onc_iort_quantity,
    surgery_one_hour_quantity,
    vad_quantity,
    update_dtm
from final;
