import { useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from "@/components/ui/button";
import { Upload, X, Loader2, Image as ImageIcon } from "lucide-react";
import { toast } from "sonner";

interface PropertyImageUploadProps {
    propertyId: string;
    onUploadComplete?: (urls: string[]) => void;
}

export default function PropertyImageUpload({ propertyId, onUploadComplete }: PropertyImageUploadProps) {
    const [uploading, setUploading] = useState(false);
    const [previews, setPreviews] = useState<string[]>([]);

    const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
        try {
            setUploading(true);
            const files = event.target.files;
            if (!files || files.length === 0) return;

            const newUrls: string[] = [];

            for (const file of Array.from(files)) {
                const fileExt = file.name.split('.').pop();
                const fileName = `${propertyId}/${Math.random()}.${fileExt}`;
                const filePath = `${fileName}`;

                const { error: uploadError, data } = await supabase.storage
                    .from('property_images')
                    .upload(filePath, file);

                if (uploadError) throw uploadError;

                const { data: { publicUrl } } = supabase.storage
                    .from('property_images')
                    .getPublicUrl(filePath);

                newUrls.push(publicUrl);

                // Track analytics event for upload
                await supabase.from('analytics_events').insert({
                    event_name: 'image_uploaded',
                    metadata: { property_id: propertyId, file_name: fileName }
                });
            }

            setPreviews(prev => [...prev, ...newUrls]);
            if (onUploadComplete) onUploadComplete(newUrls);
            toast.success(`${files.length} images uploaded successfully`);
        } catch (error: any) {
            toast.error(`Fault: ${error.message}`);
        } finally {
            setUploading(false);
        }
    };

    return (
        <div className="space-y-4">
            <div className="flex items-center justify-center w-full">
                <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-dashed border-border rounded-2xl cursor-pointer bg-secondary/20 hover:bg-secondary/40 transition-colors">
                    <div className="flex flex-col items-center justify-center pt-5 pb-6">
                        {uploading ? (
                            <Loader2 className="w-8 h-8 text-muted-foreground animate-spin" />
                        ) : (
                            <>
                                <Upload className="w-8 h-8 text-muted-foreground mb-2" />
                                <p className="text-sm text-muted-foreground">Click to upload property images</p>
                                <p className="text-xs text-muted-foreground mt-1">PNG, JPG up to 10MB</p>
                            </>
                        )}
                    </div>
                    <input
                        type="file"
                        className="hidden"
                        multiple
                        accept="image/*"
                        onChange={handleFileChange}
                        disabled={uploading}
                    />
                </label>
            </div>

            {previews.length > 0 && (
                <div className="grid grid-cols-4 gap-4">
                    {previews.map((url, idx) => (
                        <div key={idx} className="relative aspect-square rounded-xl overflow-hidden group border border-border">
                            <img src={url} alt="Preview" className="w-full h-full object-cover" />
                            <button
                                className="absolute top-1 right-1 p-1 bg-background/80 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                                onClick={() => setPreviews(prev => prev.filter((_, i) => i !== idx))}
                            >
                                <X size={12} />
                            </button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
