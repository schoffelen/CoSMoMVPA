function test_suite=test_fmri_io
    initTestSuite;

function test_fmri_io_nii_gz()
    if ~usejava('jvm') || cosmo_wtf('is_octave')
        cosmo_notify_test_skipped('java VM not available for .nii.gz');
        return;
    end

    save_and_load_dataset_with_extension('.nii.gz');

function test_fmri_io_nii()
    save_and_load_dataset_with_extension('.nii');

function test_fmri_io_hdr()
    save_and_load_dataset_with_extension('.hdr');

function test_fmri_io_img()
    save_and_load_dataset_with_extension('.img');

function test_fmri_io_afni_orig_head()
    if cosmo_skip_test_if_no_external('afni')
        return;
    end

    save_and_load_dataset_with_extension('+orig.HEAD');

function test_fmri_io_afni_tlrc_brik()
    if cosmo_skip_test_if_no_external('afni')
        return;
    end
    save_and_load_dataset_with_extension('+tlrc.BRIK');

function test_fmri_io_bv_vmp()
    if cosmo_skip_test_if_no_external('neuroelf')
        return;
    end
    save_and_load_dataset_with_extension('.vmp');

function test_fmri_io_bv_vmr()
    if cosmo_skip_test_if_no_external('neuroelf')
        return;
    end
    save_and_load_dataset_with_extension('.vmr');

function test_fmri_io_bv_msk()
    if cosmo_skip_test_if_no_external('neuroelf')
        return;
    end
    save_and_load_dataset_with_extension('.msk');

function test_fmri_io_mat()
    save_and_load_dataset_with_extension('.mat');


function save_and_load_dataset_with_extension(ext)
    x_base=get_base_dataset();
    y=save_and_load(x_base,ext);
    assert_dataset_equal(x_base,y,ext);


function test_fmri_io_exceptions()
    aet=@(varargin)assertExceptionThrown(@()...
                            cosmo_fmri_dataset(varargin{:}),'');

    fn=cosmo_make_temp_filename('test','.mat');
    cleaner=onCleanup(@()delete_files({fn}));

    x=struct();
    save(fn,'x');
    aet(fn);

    x=1;
    y=1;
    save(fn,'x','y');
    aet(fn);

    % incomplete AFNI struct
    x=struct();
    x.DATASET_DIMENSIONS=[];
    x.DATASET_RANK=[];
    aet(x);

    % illegal .mat file
    save(fn,'x');
    aet(fn);

    % wrong dimension size
    ds=cosmo_synthetic_dataset();
    nii=cosmo_map2fmri(ds,'-nii');
    nii.img=zeros(1,1,1,1,5);
    aet(nii);

function test_fmri_io_mask
    aet=@(varargin)assertExceptionThrown(@()...
                    cosmo_fmri_dataset(varargin{:}),'');

    ds=cosmo_synthetic_dataset();
    ds.sa=struct();
    m=cosmo_slice(ds,1);

    fn=cosmo_make_temp_filename('fn1','.nii');
    fn2=cosmo_make_temp_filename('fn2','.nii');

    cleaner=onCleanup(@()delete_files({fn,fn2}));

    cosmo_map2fmri(ds,fn);
    cosmo_map2fmri(m,fn2);
    x=cosmo_fmri_dataset(fn,'mask',fn2);
    assert_dataset_equal(x,ds,'.nii')

    m_rsa=cosmo_fmri_reorient(m,'RSA');
    cosmo_map2fmri(m_rsa,fn2);
    x=cosmo_fmri_dataset(fn,'mask',fn2);
    assert_dataset_equal(x,ds,'.nii')

    m_bad_fa=m;
    m_bad_fa.a.fdim.values{1}=[1 2 3 4];
    m_bad_fa.a.vol.dim(1)=4;
    m_bad_fa.fa.i=m.fa.i+1;
    cosmo_map2fmri(m_bad_fa,fn2);
    aet(fn,'mask',fn2);

    m_bad_mat=m;
    m_bad_mat.a.vol.mat(1)=3;
    cosmo_map2fmri(m_bad_mat,fn2);
    aet(fn,'mask',fn2);

    m_bad_2samples=cosmo_stack({m,m});
    cosmo_map2fmri(m_bad_2samples,fn2);
    aet(fn,'mask',fn2);

    % disable automask warning
    warning_state=cosmo_warning();
    state_resetter=onCleanup(@()cosmo_warning(warning_state));
    cosmo_warning('off');

    ds.samples(:,1:5)=0;

    res=cosmo_fmri_dataset(ds,'mask','');
    assertEqual(res,ds);

    ds.samples(1,1)=1;

    res=cosmo_fmri_dataset(ds,'mask','');
    assertEqual(res,ds);


function test_fmri_io_spm()
    cleaner=onCleanup(@()register_or_delete_all_files());
    spm_fn=build_spm_dot_mat();

    ds=cosmo_synthetic_dataset('ntargets',2,'nchunks',1);
    ds_spm=cosmo_fmri_dataset(spm_fn);

    assertEqual(ds.sa.chunks,ds_spm.sa.chunks);
    assertEqual(ds_spm.sa.beta_index,(1:2)')
    assertEqual(ds_spm.sa.labels,{'sample_1';'sample_2'});
    assertElementsAlmostEqual(ds.samples+1,ds_spm.samples,'relative',1e-4);

    input_keys={'beta','con','spm'};
    for k=1:numel(input_keys)
        key=input_keys{k};

        spm_fn_key=[spm_fn ':' key];
        ds_spm=cosmo_fmri_dataset(spm_fn_key);
        assertElementsAlmostEqual(ds.samples+k,ds_spm.samples,...
                            'relative',1e-4);
    end



function spm_fn=build_spm_dot_mat()
    register_or_delete_all_files();

    ds=cosmo_synthetic_dataset('ntargets',2,'nchunks',1);
    nsamples=size(ds.samples,1);
    input_types.beta.vols='Vbeta';
    input_types.con.vols='Vcon';
    input_types.spmT.vols='Vspm';


    input_keys=fieldnames(input_types);


    SPM=struct();
    SPM.SPMid=[];
    xCon_cell=cell(1,nsamples);

    for k=1:numel(input_keys);
        key=input_keys{k};
        is_beta=strcmp(key,'beta');

        values=input_types.(key);
        vol_label=values.vols;

        samples_offset=k;

        vol_cell=cell(1,nsamples);
        sample_labels=cell(1,nsamples);
        for j=1:nsamples
            tmp_fns=cosmo_make_temp_filename('XX',{'.hdr','.img','.mat'});
            tmp_hdr_fn=tmp_fns{1};
            tmp_img_fn=tmp_fns{2};
            tmp_mat_fn=tmp_fns{3};

            vol=ds.a.vol;
            vol.fname=tmp_hdr_fn;
            vol_cell{j}=vol;

            ds_sample=cosmo_slice(ds,j);
            ds_sample.samples=ds_sample.samples+samples_offset;
            cosmo_map2fmri(ds_sample,tmp_hdr_fn);
            sample_labels{j}=sprintf('sample_%d',j);

            register_or_delete_all_files(tmp_hdr_fn);
            register_or_delete_all_files(tmp_img_fn);
            register_or_delete_all_files(tmp_mat_fn);

            if ~is_beta
                xcon=xCon_cell{j};
                if isempty(xcon)
                    xcon=struct();
                    xcon.name=sample_labels{j};
                end
                xcon.(vol_label)=vol;
                xCon_cell{j}=xcon;
            end
        end



        vol_info=cat(2,vol_cell{:});
        if is_beta
            SPM.(vol_label)=vol_info;
        end

        if is_beta
            SPM.xX.X=[];
            SPM.Sess.Fc.i=1:2;
            SPM.Sess.col=1:2;
            SPM.xX.name=sample_labels;
        end
    end

    SPM.xCon=cat(1,xCon_cell{:});

    spm_fn='_tmp_SPM.mat';
    register_or_delete_all_files(spm_fn);
    save(spm_fn,'SPM');




function register_or_delete_all_files(fn)
    persistent files_to_delete;

    has_files_to_delete=iscell(files_to_delete);

    if nargin==0
        if has_files_to_delete
            delete_files(files_to_delete);
        end
        files_to_delete=[];
    else
        if ~has_files_to_delete
            files_to_delete=cell(0,1);
        end
        files_to_delete{end+1}=fn;
    end


function assert_dataset_equal(x,y,ext)
    funcs={@assert_samples_equal, @assert_a_equal, ...
                    @assert_fa_equal,...
                    @assert_sa_equal};
    for j=1:numel(funcs)
        func=funcs{j};
        func(x,y,ext);
    end

function assert_samples_equal(x,y,ext)
    xs=x.samples;
    ys=y.samples;
    switch ext
        case '.msk'
            assert(cosmo_corr(xs',ys')>.999);
        case '.vmr'
            assert(cosmo_corr(xs',ys')>.999);
        otherwise
            assertElementsAlmostEqual(xs,ys,'relative',1e-5);
    end


function assert_a_equal(xd,yd,ext)
    x=xd.a;
    y=yd.a;
    x.vol=rmfield_if_present(x.vol,'xform');
    y.vol=rmfield_if_present(y.vol,'xform');

    switch ext
        case '.vmr'
            % does not store the offset, so do not check it
            x.vol.mat=x.vol.mat(:,1:3);
            y.vol.mat=y.vol.mat(:,1:3);
        otherwise
            % keep as is
    end

    assertEqual(x,y);

function assert_fa_equal(x,y,ext)
    assertEqual(x.fa,y.fa);

function assert_sa_equal(x,y,ext)
    ignore_sa_exts={'.nii','.nii.gz','.hdr','.img','.vmr','.msk'};
    if cosmo_match({ext},ignore_sa_exts)
        return;
    end

    assertEqual(x.sa,y.sa);


function s=rmfield_if_present(s, f)
    if isfield(s,f)
        s=rmfield(s,f);
    end


function x=get_base_dataset()
    x=cosmo_synthetic_dataset('size','big');
    x=cosmo_fmri_reorient(x,'ASR');
    x=cosmo_slice(x,1);
    x.sa=struct();
    x.sa.labels={'labels1'};
    x.sa.stats={'Ttest(17)'};

function ds_again=save_and_load(ds,ext)
    sib_exts=get_sibling_exts(ext);

    all_exts=[{ext} sib_exts];

    temp_fns=cosmo_make_temp_filename('' ,all_exts);
    main_temp_fn=temp_fns{1};
    cleaner=onCleanup(@()delete_files(temp_fns));

    switch ext
        case '.mat'
            save(main_temp_fn,'ds');
        otherwise
            % disable automask warning
            warning_state=cosmo_warning();
            state_resetter=onCleanup(@()cosmo_warning(warning_state));
            cosmo_warning('off');

            cosmo_map2fmri(ds,main_temp_fn);
    end

    ds_again=cosmo_fmri_dataset(main_temp_fn);

function sib_exts=get_sibling_exts(ext)
    sib_exts=cell(1,0);
    switch ext
        case '.img'
            sib_exts={'.hdr','.mat'};
        case '.hdr'
            sib_exts={'.img','.mat'};
        case '+orig.HEAD'
            sib_exts={'+orig.BRIK'};
        case '+orig.BRIK'
            sib_exts={'+orig.HEAD'};
        case '+tlrc.HEAD'
            sib_exts={'+tlrc.BRIK'};
        case '+tlrc.BRIK'
            sib_exts={'+tlrc.HEAD'};
        case {'.msk','.mat','.vmr','.vmp','.nii','.nii.gz'};
            % do nothing
        otherwise
            error('unsupported extension ''%s''',ext);
    end


function delete_files(fns)
    for k=1:numel(fns)
        fn=fns{k};
        if ~isempty(fn) && exist(fn,'file')
            delete(fn);
        end
    end

