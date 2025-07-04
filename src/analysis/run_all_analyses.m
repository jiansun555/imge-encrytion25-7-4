function run_all_analyses(image_filename, main_output_base_folder)
% run_all_analyses: Executes all implemented performance analysis scripts.
%
% Args:
%   image_filename (str): Name of the image file (e.g., 'peppers.png').
%   main_output_base_folder (str): Base directory to store all analysis results.
%                                  Subfolders will be created for each analysis type.

    if nargin < 2 || isempty(main_output_base_folder)
        main_output_base_folder = '../../results/full_analysis_output';
    end
    if nargin < 1 || isempty(image_filename)
        if exist('peppers.png', 'file')
            image_filename = 'peppers.png';
        else
            error('Please provide an image filename for analysis.');
        end
    end

    % Ensure base output folder exists
    if ~exist(main_output_base_folder, 'dir')
        mkdir(main_output_base_folder);
        fprintf('Created main output folder: %s\n', main_output_base_folder);
    end

    [~, img_name_no_ext, ~] = fileparts(image_filename);

    % --- Common Parameters for Encryption and ROI detection ---
    analysis_N_psrd = 6;
    analysis_saliency_method = 'SR';
    analysis_saliency_thresh = 'auto';

    analysis_chaos_params.licc_x0 = 0.3;
    analysis_chaos_params.licc_y0 = 1.5;
    analysis_chaos_params.licc_z0 = 0.9;
    analysis_chaos_params.licc_a = 3.9;
    analysis_chaos_params.licc_b = pi;
    analysis_chaos_params.licc_c = pi;
    analysis_chaos_params.logistic_lambda_grouping = 4.0;
    analysis_chaos_params.logistic_x0_grouping = 0.5;
    analysis_chaos_params.logistic_lambda_shuffling = 3.95;
    analysis_chaos_params.logistic_x0_shuffling = 0.55;
    analysis_chaos_params.T_discard = 1000; % Standard discard

    % Image path construction (assuming image is in ../../images relative to this script's dir if in src/analysis)
    image_file_full_path = fullfile('../../images', image_filename);
    if ~exist(image_file_full_path, 'file')
        image_file_full_path = image_filename; % Try current path if not found above
        if ~exist(image_file_full_path, 'file')
            error('Image %s not found.', image_filename);
        end
    end

    fprintf('--- Running All Analyses for Image: %s ---\n', image_file_full_path);

    % --- Step 1: Perform Encryption to get Original and Encrypted ROI data ---
    % This uses the simplified encryption helper from analyze_key_sensitivity.m
    % or ideally, a call to the main encryption pipeline if it can return intermediate states.

    fprintf('\n(A) Performing initial encryption to get data for analyses...\n');
    try
        original_img_for_analysis = imread(image_file_full_path);

        % ROI Detection
        s_map = detect_saliency(image_file_full_path, analysis_saliency_method, analysis_saliency_thresh);
        ROI_info_for_analysis = psrd(s_map, analysis_N_psrd);

        % Encrypt the image
        encrypted_img_for_analysis = encrypt_image_roi_for_analysis(original_img_for_analysis, ROI_info_for_analysis, analysis_N_psrd, analysis_chaos_params);

        if isempty(encrypted_img_for_analysis)
            error('Initial encryption for analysis failed.');
        end

        % Extract ROI pixels from original and encrypted images
        % Need a consistent way to get the 1D streams of ROI pixels.
        % Using a dummy patch order for linearization, as actual order doesn't affect histogram/entropy.
        analysis_dummy_patch_order = 1:(analysis_N_psrd*analysis_N_psrd);
        % (This assumes ROI_info_for_analysis is dense and can be indexed 1 to N^2)
        % A safer way is to use ROI_info_for_analysis.patch_index for mapping if not dense.
        % For simplicity in the helper, we assume it can handle it or ROI_info is dense.

        orig_roi_pixels_cell = get_roi_pixels_from_image_for_analysis(original_img_for_analysis, ROI_info_for_analysis, analysis_dummy_patch_order);
        enc_roi_pixels_cell = get_roi_pixels_from_image_for_analysis(encrypted_img_for_analysis, ROI_info_for_analysis, analysis_dummy_patch_order);

        fprintf('Initial encryption and ROI pixel extraction complete.\n');

    catch ME_init_enc
        fprintf('ERROR during initial encryption for analysis: %s\n', ME_init_enc.message);
        disp(ME_init_enc.stack(1));
        fprintf('Aborting further analyses that depend on these results.\n');
        return;
    end

    % --- Step 2: Run Individual Analyses ---

    % a. Histogram Analysis
    try
        fprintf('\n(B) Running Histogram Analysis...\n');
        hist_output_folder = fullfile(main_output_base_folder, 'histograms');
        analyze_histogram(orig_roi_pixels_cell, enc_roi_pixels_cell, hist_output_folder, img_name_no_ext);
    catch ME_hist
        fprintf('ERROR during Histogram Analysis: %s\n', ME_hist.message);
    end

    % b. Correlation Analysis
    % analyze_correlation expects full images and ROI_info, not just pixel streams.
    try
        fprintf('\n(C) Running Correlation Analysis...\n');
        corr_output_folder = fullfile(main_output_base_folder, 'correlations');
        num_pairs_corr = 2000; % Number of pixel pairs for scatter plot
        analyze_correlation(original_img_for_analysis, encrypted_img_for_analysis, ...
                            ROI_info_for_analysis, num_pairs_corr, ...
                            corr_output_folder, img_name_no_ext);
    catch ME_corr
        fprintf('ERROR during Correlation Analysis: %s\n', ME_corr.message);
         disp(ME_corr.stack(1));
    end

    % c. Information Entropy Analysis
    try
        fprintf('\n(D) Running Information Entropy Analysis...\n');
        analyze_entropy(orig_roi_pixels_cell, enc_roi_pixels_cell);
    catch ME_entropy
        fprintf('ERROR during Information Entropy Analysis: %s\n', ME_entropy.message);
    end

    % d. Key Sensitivity Analysis
    try
        fprintf('\n(E) Running Key Sensitivity Analysis...\n');
        keysens_output_folder = fullfile(main_output_base_folder, 'key_sensitivity');
        analyze_key_sensitivity(image_file_full_path, analysis_N_psrd, analysis_saliency_method, ...
                                analysis_saliency_thresh, analysis_chaos_params, ...
                                keysens_output_folder, img_name_no_ext);
    catch ME_keysens
        fprintf('ERROR during Key Sensitivity Analysis: %s\n', ME_keysens.message);
        disp(ME_keysens.stack(1));
    end

    % e. Differential Attack Analysis
    try
        fprintf('\n(F) Running Differential Attack Analysis...\n');
        diffattack_output_folder = fullfile(main_output_base_folder, 'differential_attack');
        analyze_differential_attack(image_file_full_path, analysis_N_psrd, analysis_saliency_method, ...
                                    analysis_saliency_thresh, analysis_chaos_params, ...
                                    diffattack_output_folder, img_name_no_ext);
    catch ME_diff
        fprintf('ERROR during Differential Attack Analysis: %s\n', ME_diff.message);
        disp(ME_diff.stack(1));
    end

    fprintf('\n--- All Analyses Attempted for Image: %s ---\n', image_filename);
    fprintf('Results (if any) are in subfolders of: %s\n', main_output_base_folder);
end


% --- Helper functions (copied from other analysis files for self-containment if needed) ---
% It's better if these are in shared utility files or on path.
% For this script, we assume they are accessible via addpath or are already defined
% in the files like analyze_key_sensitivity.m if that's called.
% The `encrypt_image_roi_for_analysis` and `get_roi_pixels_from_image_for_analysis`
% are defined within `analyze_key_sensitivity.m` and `analyze_differential_attack.m`.
% If this `run_all_analyses` script is to be fully standalone for calling,
% those helpers would need to be accessible here too.
%
% For now, this script assumes that when it calls, e.g., analyze_key_sensitivity,
% that function has its own copy or access to its required helpers.
% The initial encryption performed in Step 1 here is a local re-implementation
% to get the data needed for histogram and entropy.


% --- Re-define get_roi_pixels_from_image_for_analysis locally for Step 1 ---
% (Copied from analyze_key_sensitivity.m / analyze_differential_attack.m)
function roi_pixels_cell = get_roi_pixels_from_image_for_analysis(image_matrix, ROI_info_struct, index_seg_shuffled_order)
    if isempty(ROI_info_struct) || isempty(image_matrix)
        roi_pixels_cell = {[], [], []}; return;
    end
    total_pixels_in_rois = 0;
    valid_roi_indices = [];
    for k_patch = 1:length(ROI_info_struct)
        if isfield(ROI_info_struct(k_patch),'has_roi') && ROI_info_struct(k_patch).has_roi && ~isempty(ROI_info_struct(k_patch).roi_rect)
            rect = ROI_info_struct(k_patch).roi_rect;
            total_pixels_in_rois = total_pixels_in_rois + rect(3)*rect(4);
            valid_roi_indices = [valid_roi_indices, k_patch];
        end
    end
    if total_pixels_in_rois == 0, roi_pixels_cell = {[], [], []}; return; end

    R_all=zeros(1,total_pixels_in_rois,'uint8');
    G_all=zeros(1,total_pixels_in_rois,'uint8');
    B_all=zeros(1,total_pixels_in_rois,'uint8');
    current_pixel_idx = 0;

    order_to_use = index_seg_shuffled_order;
    if isempty(order_to_use) % Fallback if no order provided: use natural order of valid ROIs
        order_to_use = [ROI_info_struct(valid_roi_indices).patch_index]; % Get patch indices of valid ROIs
    end

    for k_shuffled_idx = 1:length(order_to_use)
        patch_original_idx = order_to_use(k_shuffled_idx);

        info_entry_idx = find([ROI_info_struct.patch_index] == patch_original_idx, 1);
        if isempty(info_entry_idx), continue; end % Should not happen if order_to_use is derived from ROI_info
        info_entry = ROI_info_struct(info_entry_idx);

        if info_entry.has_roi && ~isempty(info_entry.roi_rect)
            rect = info_entry.roi_rect;
            min_c=rect(1); min_r=rect(2);
            max_c=rect(1)+rect(3)-1; max_r=rect(2)+rect(4)-1;

            for r = min_r:max_r
                for c = min_c:max_c
                    current_pixel_idx = current_pixel_idx + 1;
                    if current_pixel_idx > total_pixels_in_rois
                        error('Pixel count exceeded in get_roi_pixels (run_all_analyses helper). Expected %d, got to %d.', total_pixels_in_rois, current_pixel_idx);
                    end
                    R_all(current_pixel_idx)=image_matrix(r,c,1);
                    G_all(current_pixel_idx)=image_matrix(r,c,2);
                    B_all(current_pixel_idx)=image_matrix(r,c,3);
                end
            end
        end
    end
    % Trim if current_pixel_idx is less due to any miscalculation (should not happen)
    roi_pixels_cell = {R_all(1:current_pixel_idx), G_all(1:current_pixel_idx), B_all(1:current_pixel_idx)};
end

% --- Re-define encrypt_image_roi_for_analysis locally for Step 1 ---
% (Copied from analyze_key_sensitivity.m / analyze_differential_attack.m)
function cipher_img = encrypt_image_roi_for_analysis(plain_img, ROI_info, N, chaos_params_enc)
    [seq0_p, seq1_p, seq2_p, idx_seg_shuff, total_pix] = ...
        extract_pixels(plain_img, ROI_info, N, chaos_params_enc); % Assumes extract_pixels is on path

    if total_pix == 0, cipher_img = plain_img; fprintf('Warning: No pixels to encrypt in initial encryption (run_all_analyses).\n'); return; end

    num_pix_seq = total_pix;
    % Assumes licc_system, logistic_map, encrypt_channel are on path
    [ch_x, ch_y, ch_z] = licc_system(chaos_params_enc.licc_x0, chaos_params_enc.licc_y0, chaos_params_enc.licc_z0, ...
                                     chaos_params_enc.licc_a, chaos_params_enc.licc_b, chaos_params_enc.licc_c, ...
                                     num_pix_seq, chaos_params_enc.T_discard);
    if length(ch_x) < num_pix_seq, error('LICC failed (initial enc for run_all_analyses)'); end

    cseq0 = encrypt_channel(seq0_p, ch_x(1:num_pix_seq), 256);
    cseq1 = encrypt_channel(seq1_p, ch_y(1:num_pix_seq), 256);
    cseq2 = encrypt_channel(seq2_p, ch_z(1:num_pix_seq), 256);

    cipher_img = plain_img; % Start with copy
    num_rules_enc_an = floor(total_pix / 3);
    if num_rules_enc_an == 0 && total_pix > 0, num_rules_enc_an = 1; end
    if num_rules_enc_an == 0 && total_pix == 0, return; end % Already handled by total_pix check

    chaoseq_logi_enc_an = logistic_map(chaos_params_enc.logistic_x0_grouping, ...
                                chaos_params_enc.logistic_lambda_grouping, ...
                                num_rules_enc_an, chaos_params_enc.T_discard);
    if isempty(chaoseq_logi_enc_an) && num_rules_enc_an > 0, error('Logistic map failed for rules (initial enc for run_all_analyses).'); end
    grouping_rules_enc_an = mod(floor(abs(chaoseq_logi_enc_an) * 6), 6);

    pix_write_cnt = 0;
    for k_p_idx = 1:length(idx_seg_shuff)
        curr_p_idx = idx_seg_shuff(k_p_idx);

        info_entry_idx = find([ROI_info.patch_index] == curr_p_idx, 1);
        if isempty(info_entry_idx), continue; end
        info_e = ROI_info(info_entry_idx);

        if ~info_e.has_roi || isempty(info_e.roi_rect), continue; end
        rect_e = info_e.roi_rect;
        for r_e = rect_e(2) : (rect_e(2)+rect_e(4)-1)
            for c_e = rect_e(1) : (rect_e(1)+rect_e(3)-1)
                pix_write_cnt = pix_write_cnt + 1;
                if pix_write_cnt > total_pix, error('Pixel write count exceeded (initial enc for run_all_analyses).'); end

                val_s0 = cseq0(pix_write_cnt); val_s1 = cseq1(pix_write_cnt); val_s2 = cseq2(pix_write_cnt);
                rule_e = grouping_rules_enc_an(mod(pix_write_cnt-1, num_rules_enc_an)+1);

                % Write back logic (same as in main_encryption_system and other analysis files)
                if rule_e==0, cipher_img(r_e,c_e,:)=reshape([val_s0,val_s1,val_s2],1,1,3);
                elseif rule_e==1, cipher_img(r_e,c_e,:)=reshape([val_s0,val_s2,val_s1],1,1,3);
                elseif rule_e==2, cipher_img(r_e,c_e,:)=reshape([val_s1,val_s0,val_s2],1,1,3);
                elseif rule_e==3, cipher_img(r_e,c_e,:)=reshape([val_s2,val_s0,val_s1],1,1,3);
                elseif rule_e==4, cipher_img(r_e,c_e,:)=reshape([val_s1,val_s2,val_s0],1,1,3);
                elseif rule_e==5, cipher_img(r_e,c_e,:)=reshape([val_s2,val_s1,val_s0],1,1,3);
                end
            end
        end
    end
end

% To Run this script:
% 1. Ensure all dependent modules (chaos_systems, roi_detection, encryption, and other analysis files)
%    are on the Matlab path or in the correct relative locations.
%    E.g., if this script is in 'src/analysis/', other modules should be in 'src/chaos_systems/', etc.
%    The functions `encrypt_channel` and `decrypt_channel` are assumed to be available from `main_encryption_system.m` or `parallel_encrypt_decrypt.m`.
%    If not, they'd need to be explicitly added or defined.
% 2. Place the image to be analyzed (e.g., 'peppers.png') in an 'images' folder,
%    expected to be at '../../images/' relative to this script, or provide a full path.
% 3. Call from Matlab command window:
%    addpath(genpath('../../src')); % Or your specific project's src path
%    run_all_analyses('peppers.png', '../../results/peppers_full_analysis');
%    run_all_analyses(); % Uses defaults
%
% Note: This script calls other analysis scripts. It's crucial that those scripts
% (analyze_histogram, analyze_correlation, etc.) correctly handle their paths
% or that all necessary functions are accessible from where this is run.
% Helper functions like `encrypt_channel` are assumed to be on path.
% If they are defined as local functions in `main_encryption_system.m`, they won't be
% directly callable by these analysis scripts unless those scripts also define them or
% `main_encryption_system.m` is refactored to provide them as non-local functions.
% For this version, `encrypt_image_roi_for_analysis` includes its own calls to `encrypt_channel`.
