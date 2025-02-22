import React from 'react';
import { supabase } from '../lib/supabase';
import { ChevronRight, Edit, Save, X, Menu } from 'lucide-react';
import { cn } from '../lib/utils';
import { Editor } from '../components/Editor';
import { GuestApartment } from '../components/GuestApartment';

interface Page {
  id: string;
  title: string;
  slug: string;
  content: string;
  created_at: string;
  updated_at: string;
}

export function Home() {
  const [pages, setPages] = React.useState<Page[]>([]);
  const [selectedPage, setSelectedPage] = React.useState<Page | null>(null);
  const [isEditing, setIsEditing] = React.useState(false);
  const [content, setContent] = React.useState('');
  const [isAdmin, setIsAdmin] = React.useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = React.useState(false);
  const [saving, setSaving] = React.useState(false);

  React.useEffect(() => {
    loadPages();
    checkUser();
  }, []);

  async function checkUser() {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const { data } = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .single();
      
      setIsAdmin(data?.role === 'admin');
    }
  }

  async function loadPages() {
    try {
      const { data, error } = await supabase
        .from('pages')
        .select('*')
        .order('title');

      if (error) throw error;
      
      setPages(data || []);
      if (data?.length > 0 && !selectedPage) {
        setSelectedPage(data[0]);
        setContent(data[0].content || '');
      }
    } catch (error) {
      console.error('Error loading pages:', error);
    }
  }

  async function handleSave() {
    if (!selectedPage) return;
    setSaving(true);

    try {
      const { error } = await supabase
        .from('pages')
        .update({ 
          content,
          updated_at: new Date().toISOString()
        })
        .eq('id', selectedPage.id);

      if (error) throw error;
      
      setSelectedPage(prev => prev ? { ...prev, content } : null);
      setPages(prev => prev.map(page => 
        page.id === selectedPage.id 
          ? { ...page, content }
          : page
      ));
      
      setIsEditing(false);
    } catch (error) {
      console.error('Error saving content:', error);
    } finally {
      setSaving(false);
    }
  }

  const handlePageSelect = (page: Page) => {
    setSelectedPage(page);
    setContent(page.content || '');
    setIsEditing(false);
    setIsMobileMenuOpen(false);
  };

  return (
    <div className="flex flex-col md:flex-row h-[calc(100vh-4rem)]">
      {/* Mobile menu button */}
      <div className="md:hidden p-4 bg-white dark:bg-gray-800 shadow-sm">
        <button
          onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          className="flex items-center text-gray-700 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400"
        >
          <Menu className="h-6 w-6 mr-2" />
          {selectedPage ? selectedPage.title : 'Välj sida'}
        </button>
      </div>

      {/* Side Navigation */}
      <div
        className={cn(
          "w-full md:w-64 bg-white dark:bg-gray-800 shadow-lg overflow-y-auto",
          "md:block transition-all duration-300 ease-in-out",
          isMobileMenuOpen ? "block" : "hidden"
        )}
      >
        <nav className="p-4">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Innehåll</h2>
          <ul className="space-y-1">
            {pages.map((page) => (
              <li key={page.id}>
                <button
                  onClick={() => handlePageSelect(page)}
                  className={cn(
                    "w-full text-left px-4 py-2 rounded-lg flex items-center transition-colors",
                    selectedPage?.id === page.id
                      ? "bg-blue-50 dark:bg-blue-900 text-blue-700 dark:text-blue-300"
                      : "text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700 hover:text-blue-600 dark:hover:text-blue-400"
                  )}
                >
                  <span className="flex-1">{page.title}</span>
                  {selectedPage?.id === page.id && (
                    <ChevronRight className="h-4 w-4" />
                  )}
                </button>
              </li>
            ))}
          </ul>
        </nav>
      </div>

      {/* Content Area */}
      <div className="flex-1 overflow-y-auto p-4 md:p-8 bg-gray-50 dark:bg-gray-900">
        {selectedPage ? (
          <div>
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
              <h1 className="text-2xl md:text-3xl font-bold text-gray-900 dark:text-gray-100">
                {selectedPage.title}
              </h1>
              {isAdmin && (
                <button
                  onClick={() => isEditing ? handleSave() : setIsEditing(true)}
                  disabled={saving}
                  className={cn(
                    "flex items-center justify-center px-4 py-2 rounded-lg transition-colors",
                    isEditing
                      ? "bg-green-600 text-white hover:bg-green-700"
                      : "bg-blue-600 text-white hover:bg-blue-700",
                    saving && "opacity-50 cursor-not-allowed"
                  )}
                >
                  {isEditing ? (
                    <>
                      <Save className="h-4 w-4 mr-2" />
                      {saving ? 'Sparar...' : 'Spara'}
                    </>
                  ) : (
                    <>
                      <Edit className="h-4 w-4 mr-2" />
                      Redigera
                    </>
                  )}
                </button>
              )}
            </div>

            {isEditing ? (
              <div className="relative">
                <Editor
                  content={content}
                  onChange={setContent}
                  className="min-h-[calc(100vh-16rem)]"
                />
                <button
                  onClick={() => {
                    setIsEditing(false);
                    setContent(selectedPage.content || '');
                  }}
                  className="absolute top-2 right-2 p-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>
            ) : (
              <div>
                <div 
                  className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-md prose dark:prose-invert max-w-none min-h-[calc(100vh-16rem)]"
                  dangerouslySetInnerHTML={{ __html: selectedPage.content || '' }}
                />
                
                {/* Show GuestApartment component only for the guest apartment page */}
                {selectedPage.title === 'Gästlägenhet' && (
                  <div className="mt-8">
                    <h2 className="text-xl font-bold mb-4 text-gray-900 dark:text-gray-100">Bokningar</h2>
                    <GuestApartment />
                  </div>
                )}
              </div>
            )}
          </div>
        ) : (
          <div className="text-center text-gray-500 dark:text-gray-400 mt-8">
            Välj en sida från menyn
          </div>
        )}
      </div>
    </div>
  );
}